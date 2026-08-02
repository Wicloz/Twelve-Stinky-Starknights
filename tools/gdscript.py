#!/usr/bin/env python
"""GDScript -> Python, so the balance model can RUN the game instead of describing it.

The previous model re-implemented the rules with regex-scraped numbers, and every
new recipe/upgrade/cutscene needed a new scraping rule -- when one silently failed
to match, the model quietly modelled a game that no longer existed.

This translates the game's own source instead. Recipes, build costs, research
effects, upgrade multipliers, challenge limits and cutscene conditions are all
plain declarative GDScript, and the subset needed to execute them is small.
Anything this does NOT understand raises here or fails to compile -- loudly.

Supported subset (everything the .gd data/logic functions actually use):
    func / var / const / enum / static var / signal / class_name / extends
    var x := e | var x: T = e | var x: T          typed Array/Dictionary -> GDArray/GDDict
    inline lambdas: `f(func(a) -> R:` and `x = func() -> void:` (hoisted to nested defs)
    Foo.new(a)  ->  Foo(a)          x is Type -> isinstance(x, Type)
    true/false/null -> True/False/None          match/case
    bare identifiers that are not locals/params/globals -> self.<name>

Not supported (and not needed): await, signals with arguments, inner classes,
`@export` bodies (setters/getters are dropped -- they are sprite fitting).
"""

from __future__ import annotations

import builtins
import keyword
import re
from dataclasses import dataclass, field
from pathlib import Path

TAB = 4

_STRING = re.compile(r'"(?:[^"\\]|\\.)*"')
_MASK = re.compile(r"\x00(\d+)\x00")
_IDENT = re.compile(r"(?<![\w.])([A-Za-z_]\w*)")
_FUNC = re.compile(r"^(static\s+)?func\s+(\w+)\s*\((.*)\)\s*(?:->\s*[\w\[\], .]+)?\s*:$")
_LAMBDA = re.compile(r"\bfunc\s*\(([^()]*)\)\s*(?:->\s*[\w\[\], .]+?)?\s*:$")
_VAR = re.compile(
    r"^(?:@export\s+|@onready\s+)?(static\s+)?(var|const)\s+(\w+)\s*"
    r"(?::\s*([\w\[\], .]+?))?\s*(:?=)\s*(.*)$"
)
_VAR_BARE = re.compile(r"^(?:@export\s+)?(static\s+)?var\s+(\w+)\s*:\s*([\w\[\], .]+?)\s*:?$")
_LOCAL = re.compile(r"^\s*(?:var\s+(\w+)|for\s+(\w+)\s+in\b)")
_ENUM = re.compile(r"^enum\s+(\w+)\s*\{")
_IS = re.compile(r"\b([\w\.\[\]]+)\s+is\s+(int|float|bool|String|Array|Dictionary|[A-Z]\w*)\b")

# GDScript's built-in types, and the Python type each maps to. These are matched
# EXACTLY, not with isinstance: `false is int` is false in GDScript, but Python's
# bool subclasses int, so isinstance would silently make every unlimited Challenge
# reach its limit. Classes still use isinstance, so subclasses match.
IS_TYPES = {"Array": "list", "Dictionary": "dict", "String": "str",
            "int": "int", "float": "float", "bool": "bool"}

PY_KEYWORDS = (set(keyword.kwlist) | set(dir(builtins))
               | {"self", "True", "False", "None", "match", "case"})


class TranslationError(Exception):
    pass


# ---------------------------------------------------------------------------
# string masking -- every rewrite below is regex based, so literals are hidden
# ---------------------------------------------------------------------------
def mask(text: str) -> tuple[str, list[str]]:
    lits: list[str] = []

    def take(m: re.Match) -> str:
        lits.append(m.group(0))
        return f"\x00{len(lits) - 1}\x00"

    return _STRING.sub(take, text), lits


def unmask(text: str, lits: list[str]) -> str:
    return _MASK.sub(lambda m: lits[int(m.group(1))], text)


def strip_comment(masked: str) -> str:
    return masked.split("#", 1)[0].rstrip()


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip())


# ---------------------------------------------------------------------------
# module scanning
# ---------------------------------------------------------------------------
@dataclass
class Field:
    name: str
    type: str
    expr: str          # translated python expression (may be "None")


@dataclass
class Module:
    path: Path
    class_name: str | None = None
    extends: str | None = None
    enums: dict[str, dict[str, int]] = field(default_factory=dict)
    consts: dict[str, str] = field(default_factory=dict)
    fields: list[Field] = field(default_factory=list)
    statics: list[Field] = field(default_factory=list)
    signals: list[str] = field(default_factory=list)
    funcs: dict[str, str] = field(default_factory=dict)      # name -> python source


def split_top(text: str, sep: str = ",") -> list[str]:
    """Split on `sep` at bracket depth 0 -- `a: Dictionary[K, V], b` is two params."""
    out, depth, cur = [], 0, ""
    for ch in text:
        depth += ch in "([{"
        depth -= ch in ")]}"
        if ch == sep and depth == 0:
            out.append(cur)
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur)
    return [p.strip() for p in out if p.strip()]


def _type_test(m: re.Match) -> str:
    value, gdtype = m.group(1), m.group(2)
    if gdtype in IS_TYPES:
        return f"type({value}) is {IS_TYPES[gdtype]}"
    return f"isinstance({value}, {gdtype})"


def _percent_array(text: str) -> str:
    """`"%s" % [a, b[i]]` -> `"%s" % (a, b[i],)`, respecting nested brackets."""
    out, i = "", 0
    while True:
        m = re.compile(r"%\s*\[").search(text, i)
        if not m:
            return out + text[i:]
        depth, j = 1, m.end()
        while j < len(text) and depth:
            depth += (text[j] == "[") - (text[j] == "]")
            j += 1
        out += text[i:m.start()] + "% (" + text[m.end():j - 1] + ",)"
        i = j


class Translator:
    """Translates one file. `known` is every global name (engine builtins, autoload
    singletons, class_names); anything else a function mentions must be a member,
    so it gets `self.` -- that rule is what makes methods work without a symbol table."""

    def __init__(self, known: set[str]):
        self.known = known
        self.owner = "self"          # what an unqualified member belongs to
        self.cls = None              # the class_name of the file being translated

    # -- module ------------------------------------------------------------
    def module(self, path: Path) -> Module:
        mod = Module(path=path)
        src = path.read_text(encoding="utf-8")
        self.lits: list[str] = []
        masked, self.lits = mask(src)
        lines = [l.expandtabs(TAB) for l in masked.splitlines()]

        i = 0
        while i < len(lines):
            raw = lines[i]
            line = strip_comment(raw)
            if not line.strip() or indent_of(raw) > 0:
                i += 1
                continue
            i = self._top_level(mod, lines, i, line)
        return mod

    def _top_level(self, mod: Module, lines: list[str], i: int, line: str) -> int:
        text = line.strip()

        if text.startswith("class_name "):
            mod.class_name = self.cls = text.split()[1]
            return i + 1
        if text.startswith("extends "):
            mod.extends = text.split()[1]
            return i + 1
        if text.startswith("signal "):
            mod.signals.append(re.split(r"[ (]", text[7:].strip())[0])
            return i + 1
        if text.startswith("@tool") or text.startswith("@icon"):
            return i + 1

        m = _ENUM.match(text)
        if m:
            body, i = self._join(lines, i)
            return self._enum(mod, m.group(1), body, i)

        m = _FUNC.match(text)
        if m:
            return self._func(mod, lines, i, m)

        m = _VAR_BARE.match(text)
        if m and not text.endswith(("=", ",")):
            static, name, typ = m.groups()
            (mod.statics if static else mod.fields).append(
                Field(name, typ, self._container_default(typ)))
            i += 1
            while i < len(lines) and (not lines[i].strip() or indent_of(lines[i]) > 0):
                i += 1                       # drop setter/getter blocks (sprite fitting)
            return i

        body, i = self._join(lines, i)
        m = _VAR.match(body.strip())
        if m:
            static, kind, name, typ, _eq, expr = m.groups()
            # a member's default may name another member: those resolve against the
            # class body, so they must NOT be turned into self.<name>
            py = unmask(self.expr(expr, locals_=self._declared(mod)), self.lits)
            if typ and typ.startswith("Array"):
                py = f"GDArray({py})"
            elif typ and typ.startswith("Dictionary"):
                py = f"GDDict({py})"
            if kind == "const":
                mod.consts[name] = py
            elif static:
                mod.statics.append(Field(name, typ or "", py))
            else:
                mod.fields.append(Field(name, typ or "", py))
            return i
        raise TranslationError(f"{mod.path.name}: cannot read top-level line: {body!r}")

    def _declared(self, mod: Module) -> set[str]:
        return (set(mod.enums) | set(mod.consts)
                | {f.name for f in mod.fields} | {f.name for f in mod.statics})

    def _join(self, lines: list[str], i: int) -> tuple[str, int]:
        """Join a statement that continues while its brackets are unbalanced."""
        text = strip_comment(lines[i])
        i += 1
        while text.count("(") + text.count("[") + text.count("{") > \
                text.count(")") + text.count("]") + text.count("}"):
            if i >= len(lines):
                raise TranslationError(f"unterminated statement: {text!r}")
            text += " " + strip_comment(lines[i]).strip()
            i += 1
        return text, i

    def _enum(self, mod: Module, name: str, body: str, i: int) -> int:
        inner = body[body.index("{") + 1: body.rindex("}")]
        members: dict[str, int] = {}
        nxt = 0
        for part in inner.split(","):
            part = part.strip()
            if not part:
                continue
            if "=" in part:
                key, val = part.split("=", 1)
                nxt = int(val.strip())
                members[key.strip()] = nxt
            else:
                members[part] = nxt
            nxt += 1
        mod.enums[name] = members
        return i

    def _container_default(self, typ: str) -> str:
        if typ.startswith("Array"):
            return "GDArray()"
        if typ.startswith("Dictionary"):
            return "GDDict()"
        return "None"

    def _func(self, mod: Module, lines: list[str], i: int, m: re.Match) -> int:
        static, name, params = m.group(1), m.group(2), m.group(3)
        start = i
        i += 1
        body: list[str] = []
        while i < len(lines):
            raw = lines[i]
            if raw.strip() and indent_of(raw) == 0:
                break
            body.append(raw)
            i += 1
        if not any(l.strip() for l in body):
            raise TranslationError(f"{mod.path.name}: empty func {name} at line {start}")
        args = self.params(params)
        head = args if static else "self" + (", " if args else "") + args
        # a static func has no `self`, so its members hang off the class itself
        self.owner = mod.class_name if static else "self"
        src = [f"def {name}({head}):"]
        src += self.body(body, locals_=self.locals(body, params))
        self.owner = "self"
        mod.funcs[name] = unmask("\n".join(src), self.lits)
        return i

    # -- statements --------------------------------------------------------
    def locals(self, body: list[str], params: str) -> set[str]:
        out = {p.split(":")[0].split("=")[0].strip() for p in split_top(params)}
        for line in body:
            m = _LOCAL.match(strip_comment(line))
            if m:
                out.add(m.group(1) or m.group(2))
            for lm in _LAMBDA.finditer(strip_comment(line)):
                out |= {p.split(":")[0].strip() for p in split_top(lm.group(1))}
        return out

    def body(self, lines: list[str], locals_: set[str]) -> list[str]:
        out: list[str] = []
        pending: list[tuple[int, str]] = []          # (indent, "prefix + lambda name")
        match_at: list[int] = []                     # indents of open `match` blocks
        n = 0
        for raw in lines:
            line = strip_comment(raw)
            if not line.strip():
                continue
            ind = indent_of(line)
            while pending and ind <= pending[-1][0]:
                pind, text = pending.pop()
                out.append(" " * pind + text)
            while match_at and ind <= match_at[-1]:
                match_at.pop()

            text = line.strip()
            m = _LAMBDA.search(text)
            if m:
                name = f"_lambda{n}"
                n += 1
                out.append(" " * ind + f"def {name}({self.params(m.group(1))}):")
                pending.append((ind, self.statement(text[:m.start()] + name, locals_)))
                continue

            if match_at and ind == match_at[-1] + TAB and text.endswith(":"):
                out.append(" " * ind + "case " + self.expr(text[:-1], locals_) + ":")
                continue
            if re.match(r"^match\s+.*:$", text):
                out.append(" " * ind + "match " + self.expr(text[6:-1], locals_) + ":")
                match_at.append(ind)
                continue
            out.append(" " * ind + self.statement(text, locals_))
        while pending:
            pind, text = pending.pop()
            out.append(" " * pind + text)
        return out

    def statement(self, text: str, locals_: set[str]) -> str:
        m = _VAR.match(text)
        if m:
            _static, _kind, name, typ, _eq, expr = m.groups()
            py = self.expr(expr, locals_)
            if typ and typ.startswith("Array"):
                py = f"GDArray({py})"
            elif typ and typ.startswith("Dictionary"):
                py = f"GDDict({py})"
            return f"{name} = {py}"
        m = _VAR_BARE.match(text)
        if m:
            return f"{m.group(2)} = {self._container_default(m.group(3))}"
        return self.expr(text, locals_)

    def params(self, params: str) -> str:
        out = []
        for p in split_top(params):
            name, _, default = p.partition("=")
            name = name.split(":")[0].strip()
            out.append(f"{name}={self.expr(default.strip(), set())}" if default else name)
        return ", ".join(out)

    # -- expressions -------------------------------------------------------
    def expr(self, text: str, locals_: set[str]) -> str:
        t = text
        t = t.replace(".new(", "(")
        t = re.sub(r"\s+as\s+[A-Z]\w*", "", t)                  # casts are hints only
        # these methods are exec'd outside a class body, so the zero-argument
        # super() has no __class__ cell to find -- name the class explicitly
        t = re.sub(r"\bsuper\.", f"super({self.cls}, self).", t)
        t = re.sub(r"\.to_lower\(\)", ".lower()", t)             # String API
        t = re.sub(r"\.to_upper\(\)", ".upper()", t)
        t = re.sub(r"\.is_valid\(\)", " is not None", t)         # Callable API
        t = re.sub(r"\.call\(", "(", t)
        t = re.sub(r"([\w.]+)\.bind\(([^()]*)\)", r"bind(\1, \2)", t)
        t = _percent_array(t)                                    # "%s" % [a] -> tuple
        t = _IS.sub(_type_test, t)
        t = re.sub(r"\btrue\b", "True", t)
        t = re.sub(r"\bfalse\b", "False", t)
        t = re.sub(r"\bnull\b", "None", t)
        t = re.sub(r"\belif\b", "elif", t)
        t = re.sub(r"\b(\d[\d_]*)\b", lambda m: m.group(1).replace("_", ""), t)
        return self.qualify(t, locals_)

    def qualify(self, text: str, locals_: set[str]) -> str:
        def repl(m: re.Match) -> str:
            name = m.group(1)
            if (name in PY_KEYWORDS or name in locals_ or name in self.known
                    or name.startswith("_lambda")):
                return name
            return f"{self.owner}.{name}"

        return _IDENT.sub(repl, text)
