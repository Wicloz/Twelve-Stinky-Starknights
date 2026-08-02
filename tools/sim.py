#!/usr/bin/env python
"""A headless run of 12 Stinky Starknights.

This is not a model of the game -- it IS the game, minus rendering: every rule
that matters for pacing (jobs, walking, crafting, research, challenges, the
cutscene clock) is executed straight out of the .gd sources by tools/gdscript.py.
What is written here is only what the ENGINE would have provided:

  * a fixed-timestep tree that calls _process(delta) and runs SceneTreeTimers,
  * Vector2 / typed Array / Dictionary / signals / enums,
  * the map and crew, loaded from world.tscn,
  * the four spots the game `await`s an engine timer (automated factory and
    extraction runs, the cutscene delay, and the cutscene text reveal that
    StoryUI drives), rewritten as timer callbacks.

Everything else -- Stockpile, JobManager, Catalog, Crafting, Research, Story,
HexTile, Building, FactoryBuilding, ExtractionBuilding, Workshop, Warehouse,
Starknight and every building's research tree -- is the game's own code.

The one deliberate deviation is Starknight.travel_time(), which is answered from
a precomputed path table instead of walking the path list. It returns the same
number; the JobManager asks for it thousands of times a second.
"""

from __future__ import annotations

import heapq
import math
import random
import re
from dataclasses import dataclass
from pathlib import Path

from gdscript import Translator, TranslationError

GAME = Path(__file__).resolve().parent.parent
INF = math.inf


# ===========================================================================
# Engine value types
# ===========================================================================
class Vector2:
    __slots__ = ("x", "y")

    def __init__(self, x: float = 0.0, y: float = 0.0):
        self.x, self.y = float(x), float(y)

    def distance_to(self, o: "Vector2") -> float:
        return math.hypot(self.x - o.x, self.y - o.y)

    def move_toward(self, o: "Vector2", delta: float) -> "Vector2":
        dx, dy = o.x - self.x, o.y - self.y
        d = math.hypot(dx, dy)
        if d <= delta or d == 0.0:
            return Vector2(o.x, o.y)
        return Vector2(self.x + dx / d * delta, self.y + dy / d * delta)

    def __eq__(self, o) -> bool:
        return isinstance(o, Vector2) and self.x == o.x and self.y == o.y

    def __repr__(self) -> str:
        return f"({self.x:.0f},{self.y:.0f})"


class GDArray(list):
    """Godot's Array API on top of list."""

    def append(self, v):                      # returns None like list.append
        list.append(self, v)

    def push_front(self, v):
        self.insert(0, v)

    def pop_front(self):
        return self.pop(0) if self else None

    def remove_at(self, i):
        del self[i]

    def erase(self, v):
        try:
            self.remove(v)
        except ValueError:
            pass

    def has(self, v):
        return v in self

    def is_empty(self):
        return not self

    def size(self):
        return len(self)

    def duplicate(self):
        return GDArray(self)

    def filter(self, fn):
        return GDArray(x for x in self if fn(x))

    def assign(self, other):
        self[:] = list(other)

    def shuffle(self):
        RNG.shuffle(self)

    def pick_random(self):
        return RNG.choice(self) if self else None

    def find(self, v):
        return self.index(v) if v in self else -1


class GDDict(dict):
    def has(self, k):
        return k in self

    def erase(self, k):
        self.pop(k, None)

    def is_empty(self):
        return not self

    def size(self):
        return len(self)

    def keys(self):
        return GDArray(dict.keys(self))

    def values(self):
        return GDArray(dict.values(self))

    def duplicate(self):
        return GDDict(self)


class Signal:
    def __init__(self):
        self._slots = []

    def connect(self, fn):
        if fn not in self._slots:
            self._slots.append(fn)

    def emit(self, *args):
        for fn in list(self._slots):
            fn(*args)


class GDEnum:
    """`enum X {A, B}` -- attribute access plus values()/keys(), and a reverse map."""

    def __init__(self, name: str, members: dict[str, int]):
        self._name, self._members = name, members
        self._by_value = {v: k for k, v in members.items()}
        for k, v in members.items():
            setattr(self, k, v)

    def values(self):
        return GDArray(self._members.values())

    def keys(self):
        return GDArray(self._members.keys())

    def name_of(self, value):
        return self._by_value.get(value, str(value))


class Res:
    """What preload() gives back: a resource path, plus instantiate() for scenes."""

    SCENES: dict[str, type] = {}
    EXPORTS: dict[str, dict] = {}

    def __init__(self, path: str):
        self.path = path

    def instantiate(self):
        node = Res.SCENES[self.path]()
        for k, v in Res.EXPORTS.get(self.path, {}).items():
            setattr(node, k, v)
        return node

    def get_size(self):
        return Vector2(1, 1)

    def __repr__(self):
        return f"Res({self.path})"


class Dummy:
    """Stands in for the nodes only the renderer cares about (sprites, bars)."""

    def __getattr__(self, name):
        if name.startswith("__"):
            raise AttributeError(name)
        return Dummy()

    def __setattr__(self, name, value):
        pass

    def __call__(self, *a, **k):
        return Dummy()

    def __bool__(self):
        return False


RNG = random.Random(0)


# ===========================================================================
# Engine node tree
# ===========================================================================
class Node:
    def __init__(self):
        self.name = type(self).__name__
        self.position = Vector2()
        self._children: list[Node] = []
        self._freed = False

    def add_child(self, child: "Node"):
        self._children.append(child)
        TREE.enter(child)

    def get_tree(self):
        return TREE

    def queue_free(self):
        TREE.free(self)

    def get_node(self, _path):
        return Dummy()

    def get_script(self):
        return type(self)


class Timer(Node):
    def __init__(self):
        super().__init__()
        self.wait_time = 1.0
        self.one_shot = False
        self.timeout = Signal()

    def start(self):
        TREE.repeat(self.wait_time, self.timeout.emit)


class Tree:
    """Fixed-timestep stand-in for SceneTree: _process(delta) plus create_timer()."""

    def __init__(self, dt: float):
        self.dt = dt
        self.now = 0.0
        self._timers: list[tuple[float, int, object]] = []
        self._seq = 0
        self._processing: list[Node] = []

    # -- lifecycle
    def enter(self, node: Node):
        if hasattr(type(node), "_process"):
            self._processing.append(node)
        ready = getattr(node, "_ready", None)
        if ready:
            ready()

    def free(self, node: Node):
        node._freed = True
        if node in self._processing:
            self._processing.remove(node)

    # -- timers
    def create_timer(self, delay: float, callback=None):
        self._seq += 1
        heapq.heappush(self._timers, (self.now + delay, self._seq, callback))
        return Dummy()

    def repeat(self, period: float, callback):
        def fire():
            callback()
            self.create_timer(period, fire)

        self.create_timer(period, fire)

    # -- frame
    def tick(self):
        self.now += self.dt
        while self._timers and self._timers[0][0] <= self.now:
            _t, _s, cb = heapq.heappop(self._timers)
            if cb:
                cb()
        for node in list(self._processing):
            if not node._freed:
                node._process(self.dt)


TREE: Tree = None            # set by Game()


# ===========================================================================
# Loading the GDScript sources into live Python classes
# ===========================================================================
ENGINE_NAMES = {
    "INF", "PI", "NAN", "Vector2", "Vector2i", "Timer", "Callable", "Script",
    "Texture2D", "VideoStream", "AudioStream", "PackedScene", "Node", "Node2D",
    "ProgressBar", "Sprite2D", "AStar2D", "Color", "Tween", "PackedStringArray",
    "FileAccess", "Engine", "Time", "ProjectSettings", "preload", "load", "bind",
    "ceili", "floori", "roundi", "roundf", "absi", "absf", "maxf", "minf",
    "clampf", "randf_range", "str", "int", "float", "bool", "len", "range",
    "print", "push_warning", "isinstance", "GDArray", "GDDict", "min", "max",
    "is_equal_approx", "snappedf", "signf", "posmod", "lerpf",
}
AUTOLOADS = ["Stockpile", "ZaWarudo", "JobManager", "Crafting", "Catalog",
             "Research", "Story", "ActivityLog"]


def _class_names() -> set[str]:
    names = set()
    for path in GAME.glob("**/*.gd"):
        m = re.search(r"^class_name\s+(\w+)", path.read_text(encoding="utf-8"), re.M)
        if m:
            names.add(m.group(1))
    return names


def bind(fn, *args):
    return lambda *rest: fn(*rest, *args)


class Loader:
    def __init__(self, ns: dict):
        self.ns = ns
        self.tr = Translator(set(ns) | ENGINE_NAMES | set(AUTOLOADS) | _class_names())

    def build(self, rel: str, bases=(), skip=(), skip_fields=(), extra=None) -> type:
        """Turn one .gd file into a Python class. `skip` drops methods this file
        implements with engine features (await, tweens); they must be supplied in
        `extra` or by a base class."""
        mod = self.tr.module(GAME / rel)
        attrs: dict[str, object] = {"__gd__": mod}

        for name, members in mod.enums.items():
            attrs[name] = GDEnum(name, members)
        for name, expr in mod.consts.items():
            attrs[name] = eval(expr, self.ns, attrs)
        for f in mod.statics:
            attrs[f.name] = eval(f.expr, self.ns, attrs)

        fields = [f for f in mod.fields if f.name not in skip_fields]
        codes = [(f.name, compile(f.expr, f"<{rel}:{f.name}>", "eval")) for f in fields]
        signals = list(mod.signals)
        base_init = bases[0].__init__ if bases else Node.__init__

        ns = self.ns

        def __init__(self, *args, _codes=codes, _signals=signals, _base=base_init,
                     _attrs=attrs):
            _base(self)
            for sig in _signals:
                setattr(self, sig, Signal())
            for name, code in _codes:
                setattr(self, name, eval(code, ns, _attrs))
            init = getattr(self, "_init", None)     # GDScript's own constructor
            if init:
                init(*args)

        attrs["ns_"] = self.ns
        attrs["__init__"] = __init__

        for name, src in mod.funcs.items():
            if name in skip:
                continue
            scope: dict = {}
            try:
                exec(compile(src, f"<{rel}:{name}>", "exec"), self.ns, scope)
            except SyntaxError as e:
                raise TranslationError(f"{rel}.{name}: {e}\n{src}") from None
            fn = scope[name]
            attrs[name] = staticmethod(fn) if _is_static(src) else fn
        attrs.update(extra or {})

        cls = type(mod.class_name or Path(rel).stem, bases or (Node,), attrs)
        self.ns[cls.__name__] = cls
        return cls


def _is_static(src: str) -> bool:
    return not re.match(r"def \w+\(self\b|def \w+\(self,", src)


# ===========================================================================
# The parts the engine, not the game, is responsible for
# ===========================================================================
class World:
    """ZaWarudo: the hex graph. Paths are shortest in hops (AStar2D scores every
    edge 1.0), ties broken by the shorter walk, which is what a player sees."""

    NEIGHBORS = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)]

    def __init__(self):
        self.tiles: dict[tuple[int, int], object] = {}
        self._prev: dict[tuple, dict] = {}       # BFS parents, per source tile
        self._paths: dict[tuple, GDArray] = {}
        self._hop: dict[tuple, object] = {}
        self._len: dict[tuple, float] = {}

    def build(self, tiles: dict):
        self.tiles = tiles
        for coord, tile in tiles.items():
            if tile.walkable:
                self._explore(coord)

    def _explore(self, source):
        """Dijkstra on (hops, pixels) from `source` over walkable tiles."""
        start = self.tiles[source]
        best = {source: (0, 0.0)}
        prev: dict[tuple, tuple] = {}
        queue = [(0, 0.0, source)]
        while queue:
            hops, walk, coord = heapq.heappop(queue)
            if (hops, walk) > best.get(coord, (INF, INF)):
                continue
            here = self.tiles[coord]
            for dq, dr in self.NEIGHBORS:
                nb = (coord[0] + dq, coord[1] + dr)
                tile = self.tiles.get(nb)
                if tile is None or not tile.walkable:
                    continue
                cand = (hops + 1, walk + here.position.distance_to(tile.position))
                if cand < best.get(nb, (INF, INF)):
                    best[nb] = cand
                    prev[nb] = coord
                    heapq.heappush(queue, (cand[0], cand[1], nb))
        for coord, (_hops, walk) in best.items():
            self._len[(source, coord)] = walk
            step = coord
            while prev.get(step, source) != source and step != source:
                step = prev[step]
            self._hop[(source, coord)] = self.tiles[step] if step != source else start
        self._prev[source] = prev

    # -- the API the game calls
    def find_path(self, frm, to) -> GDArray:
        frm, to = (frm.x, frm.y) if hasattr(frm, "x") else frm, (to.x, to.y) if hasattr(to, "x") else to
        key = (frm, to)
        if key not in self._paths:
            prev = self._prev.get(frm, {})
            if to != frm and to not in prev:
                self._paths[key] = GDArray()
            else:
                path, step = [], to
                while step != frm:
                    path.append(self.tiles[step])
                    step = prev[step]
                path.reverse()
                self._paths[key] = GDArray(path)
        return GDArray(self._paths[key])

    def walkable_neighbors(self, coord) -> GDArray:
        coord = (coord.x, coord.y) if hasattr(coord, "x") else coord
        out = GDArray()
        for dq, dr in self.NEIGHBORS:
            tile = self.tiles.get((coord[0] + dq, coord[1] + dr))
            if tile and tile.walkable:
                out.append(tile)
        return out

    # -- what travel_time() needs
    def hop(self, frm, to):
        return self._hop.get(((frm.q, frm.r), (to.q, to.r)))

    def walk_length(self, frm, to) -> float:
        return self._len.get(((frm.q, frm.r), (to.q, to.r)), INF)


class Vector2i(tuple):
    def __new__(cls, q, r):
        return super().__new__(cls, (q, r))

    x = property(lambda self: self[0])
    y = property(lambda self: self[1])


class ActivityLog:
    """The game's own action log (scripts/globals/ActivityLog.gd), minus the file
    writing: kind / name / tile / detail, timestamped. This is the model's
    timeline -- the same call sites the real game records."""

    def __init__(self):
        self.entries: list[dict] = []

    def elapsed(self):
        return TREE.now

    def record(self, kind, name, tile, detail=""):
        self.entries.append(dict(seconds=TREE.now, kind=kind, name=name,
                                 q=tile.q if tile else 0, r=tile.r if tile else 0,
                                 detail=detail))

    def record_research(self, item, building):
        kind = "upgrade"
        if item.display_name == "Automation":
            kind = "automate"
        elif type(building).__name__ == "Workshop":
            kind = "research"
        elif type(building).__name__ == "Warehouse":
            kind = "wresearch"
        self.record(kind, item.display_name, building.tile, building.get_display_name())


@dataclass
class Cut:
    scene: object
    start: float
    end: float


class CutscenePlayer:
    """scripts/StoryUI.gd: reveals the text, then tells Story it is done. A
    cutscene lasts max(visible_chars / typing_speed, min_duration)."""

    def __init__(self, story):
        self.story = story
        self.played: list[Cut] = []
        story.cutscene_started.connect(self._on_started)
        story.play_next()

    def _on_started(self, cutscene):
        chars = max(0, len(re.sub(r"\[/?[^\]]*\]", "", cutscene.text)) - 2)
        type_time = chars / cutscene.typing_speed if cutscene.typing_speed > 0 else 0.0
        total = max(type_time, cutscene.min_duration)
        self.played.append(Cut(cutscene, TREE.now, TREE.now + total))
        TREE.create_timer(total, self.story.finish_current)


# ===========================================================================
# The game
# ===========================================================================
class Game:
    def __init__(self, dt: float = 1.0 / 30.0, seed: int = 0):
        global TREE
        TREE = Tree(dt)
        RNG.seed(seed)

        ns: dict = dict(
            INF=INF, PI=math.pi, NAN=math.nan, Vector2=Vector2, Vector2i=Vector2i,
            Timer=Timer, Node=Node, Node2D=Node, GDArray=GDArray, GDDict=GDDict,
            preload=Res, load=Res, bind=bind, Dummy=Dummy,
            ceili=lambda x: int(math.ceil(x)), floori=lambda x: int(math.floor(x)),
            roundi=lambda x: int(round(x)), roundf=round,
            absi=abs, absf=abs, maxf=max, minf=min,
            clampf=lambda v, lo, hi: max(lo, min(hi, v)),
            randf_range=lambda a, b: RNG.uniform(a, b),
            is_equal_approx=lambda a, b: abs(a - b) <= 1e-6 * max(1.0, abs(a), abs(b)),
            signf=lambda x: math.copysign(1.0, x), lerpf=lambda a, b, t: a + (b - a) * t,
            push_warning=lambda *a: None, Engine=Dummy(), Time=Dummy(),
            str=str, int=int, float=float, bool=bool, len=len, range=range,
            print=print, isinstance=isinstance, min=min, max=max,
        )
        self.ns = ns
        loader = Loader(ns)

        # -- plain data classes -------------------------------------------
        loader.build("scripts/Recipe.gd")
        loader.build("scripts/StockpileItem.gd")
        loader.build("scripts/ResearchItem.gd")
        loader.build("scripts/Cutscene.gd")
        loader.build("scripts/Challenge.gd")
        loader.build("scripts/Job.gd")
        self.CatalogItem = loader.build("scripts/CatalogItem.gd", skip=("_try_scene_probe",),
                                        extra=dict(_try_scene_probe=_probe_scene))

        # -- autoloads (project.godot order) -------------------------------
        ns["ZaWarudo"] = self.world = World()
        ns["ActivityLog"] = self.log = ActivityLog()
        self.Stockpile = loader.build("scripts/globals/Stockpile.gd")
        self.JobManager = loader.build("scripts/globals/JobManager.gd")
        self.Crafting = loader.build("scripts/globals/Crafting.gd")
        self.Catalog = loader.build("scripts/globals/Catalog.gd")
        self.Research = loader.build("scripts/globals/Research.gd")
        self.Story = loader.build("scripts/globals/Story.gd",
                                  skip=("_try_play_next",),
                                  extra=dict(_try_play_next=_story_try_play_next,
                                             _cooldown_done=_story_cooldown_done))

        # -- nodes ----------------------------------------------------------
        loader.build("objects/HexTile.gd")
        loader.build("objects/Starknight.gd", skip=("travel_time", "_path_to"),
                     skip_fields=("_progress_bar",),
                     extra=dict(_progress_bar=Dummy(), travel_time=_travel_time,
                                _path_to=_path_to))
        building = loader.build("scripts/Building.gd",
                                skip=("multiply_by_this", "_fit_sprite_to_tile"),
                                skip_fields=("_sprite_holder", "_sprite"),
                                extra=dict(_sprite=Dummy(),
                                           multiply_by_this=lambda self: 1.0,
                                           _fit_sprite_to_tile=lambda self: None))
        factory = loader.build("scripts/FactoryBuilding.gd", bases=(building,),
                               skip=("_try_automated_run",), skip_fields=("recipe",),
                               extra=dict(recipe=0,      # @export default, as Godot
                                          _try_automated_run=_factory_automated_run,
                                          _automated_done=_factory_automated_done))
        extraction = loader.build("scripts/ExtractionBuilding.gd", bases=(building,),
                                  skip=("_automated_run",),
                                  extra=dict(_automated_run=_extraction_automated_run,
                                             _automated_done=_extraction_automated_done))
        bases = {"Building": building, "FactoryBuilding": factory,
                 "ExtractionBuilding": extraction}
        self.building_classes = {}
        for path in sorted((GAME / "objects/buildings").glob("*.gd")):
            base = re.search(r"^extends\s+(\w+)", path.read_text(encoding="utf-8"), re.M)
            cls = loader.build(f"objects/buildings/{path.name}",
                               bases=(bases[base.group(1)],))
            self.building_classes[cls.__name__] = cls
            scene = f"res://objects/buildings/{path.stem}.tscn"
            Res.SCENES[scene] = cls
            Res.EXPORTS[scene] = _scene_exports(GAME / f"objects/buildings/{path.stem}.tscn")
            for key, value in Res.EXPORTS[scene].items():
                setattr(cls, key, value)     # a building class has exactly one scene

        # -- instantiate the autoloads -------------------------------------
        self.stockpile = ns["Stockpile"] = self.Stockpile()
        self.jobs = ns["JobManager"] = self.JobManager()
        self.crafting = ns["Crafting"] = self.Crafting()
        self.catalog = ns["Catalog"] = self.Catalog()
        self.research = ns["Research"] = self.Research()
        for node in (self.stockpile, self.jobs, self.crafting, self.catalog):
            if hasattr(node, "_ready"):
                node._ready()

        # -- the world scene -------------------------------------------------
        self._load_world()
        self.story = ns["Story"] = self.Story()
        made: list = []
        _watch_construction(ns["Cutscene"], made)
        self.story._ready()
        # cutscenes are anonymous objects; they are constructed in the order
        # Story.gd declares them, which is how they get their names back
        names = re.findall(r"var (\w+) := Cutscene\.new\(\)",
                           (GAME / "scripts/globals/Story.gd").read_text(encoding="utf-8"))
        for name, cutscene in zip(names, made):
            cutscene.var_name = name
        self.cutscenes = CutscenePlayer(self.story)

        self.items = self.Stockpile.ItemType
        self.item_name = {v: self.stockpile.get_display_name(v)
                          for v in self.items.values() if v}

    # -- world.tscn ---------------------------------------------------------
    def _load_world(self):
        HexTile, Starknight = self.ns["HexTile"], self.ns["Starknight"]
        text = (GAME / "world.tscn").read_text(encoding="utf-8")
        tiles, speeds, workshop_at = {}, [], None
        for block in text.split("\n[node ")[1:]:
            head, _, body = block.partition("\n")
            fields = dict(re.findall(r"^(\w+) = (.+)$", body, re.M))

            def num(key, default=0.0):
                return float(fields.get(key, default))

            if head.startswith('name="Tile='):
                tile = HexTile()
                tile.q, tile.r = int(num("q")), int(num("r"))
                pos = re.match(r"Vector2\((-?[\d.]+), (-?[\d.]+)\)", fields.get("position", ""))
                tile.position = Vector2(float(pos.group(1)), float(pos.group(2))) if pos else Vector2()
                tile.walkable = fields.get("walkable", "true") == "true"
                tile.workable = fields.get("workable", "false") == "true"
                tile.deposit = int(num("deposit"))
                tiles[(tile.q, tile.r)] = tile
                if 'NodePath("Workshop")' in fields.get("building", ""):
                    workshop_at = tile
            elif head.startswith('name="Starknight'):
                speeds.append(num("move_speed", 100.0))

        self.tiles = tiles
        self.world.build(tiles)

        self.workshop = self.building_classes["Workshop"]()
        self.workshop.tile = workshop_at
        workshop_at.building = self.workshop
        TREE.enter(self.workshop)
        self.catalog.building_finished_construction(type(self.workshop))

        self.knights = []
        for speed in speeds:
            knight = Starknight()
            knight.move_speed = speed
            knight.start_tile = workshop_at
            TREE.enter(knight)
            self.knights.append(knight)

    def register_all_research(self):
        """Register every building's research tree up front.

        The game registers a tree the first time one of that building is raised
        (Research.can_register keys on the script, and every effect closure
        captures the script rather than the instance -- see FactoryBuilding.gd).
        Doing it early changes nothing about what the player can click, since
        Research.available_for() is asked per BUILT building; it just lets the
        model see the whole tech tree, which a player reading the wiki also can."""
        for cls in self.building_classes.values():
            define = getattr(cls, "_define_research", None)
            if define:
                define(cls())

    # -- running ------------------------------------------------------------
    def tick(self):
        TREE.tick()

    @property
    def now(self):
        return TREE.now


# ---------------------------------------------------------------------------
# the engine-coupled methods the loader skips
# ---------------------------------------------------------------------------
def _travel_time(self, target):
    """objects/Starknight.gd travel_time(), from the precomputed path table."""
    footing = self._footing()
    if footing is None:
        return INF
    world = self.ns_["ZaWarudo"]
    if self._wander_tile:
        rest = 0.0 if target is self._wander_tile else world.walk_length(self._wander_tile, target)
        if rest == INF:
            return INF
        return (self.position.distance_to(self._wander_tile.position) + rest) / self._get_speed()
    if target is footing:
        return 0.0
    hop = world.hop(footing, target)
    if hop is None:
        return INF
    return (self.position.distance_to(hop.position)
            + world.walk_length(hop, target)) / self._get_speed()


def _path_to(self, target):
    """objects/Starknight.gd _path_to()."""
    footing = self._footing()
    path = GDArray()
    if target is not footing:
        path = self.ns_["ZaWarudo"].find_path(Vector2i(footing.q, footing.r),
                                              Vector2i(target.q, target.r))
        if path.is_empty():
            return GDArray()
    if self._wander_tile:
        path.push_front(self._wander_tile)
    return path


def _factory_automated_run(self):
    """scripts/FactoryBuilding.gd _try_automated_run(), await -> timer."""
    if not self._try_consume():
        return
    self._has_active_job = True
    TREE.create_timer(self._duration(), self._automated_done)


def _factory_automated_done(self):
    if not self._has_active_job:
        return
    self.ns_["Stockpile"].add_bulk(self._will_produce)
    self._has_active_job = False


def _extraction_automated_run(self):
    """scripts/ExtractionBuilding.gd _automated_run(), await -> timer."""
    self._has_active_job = True
    self._determine_harvest()
    TREE.create_timer(self._duration(), self._automated_done)


def _extraction_automated_done(self):
    if not self._has_active_job:
        return
    self.ns_["Stockpile"].add_bulk(self._will_harvest)
    self._has_active_job = False


def _story_try_play_next(self):
    """scripts/globals/Story.gd _try_play_next(), await -> timer."""
    if self._current_cutscene or self._cooldown or self._cutscene_queue.is_empty():
        return
    self._cooldown = True
    TREE.create_timer(self.DELAY_BETWEEN_CUTSCENES, self._cooldown_done)


def _story_cooldown_done(self):
    self._cooldown = False
    self._current_cutscene = self._cutscene_queue.pop_front()
    self.cutscene_started.emit(self._current_cutscene)


def _watch_construction(cls: type, out: list):
    original = cls.__init__

    def __init__(self, *args, **kw):
        original(self, *args, **kw)
        out.append(self)

    cls.__init__ = __init__


def _probe_scene(self):
    """scripts/CatalogItem.gd _try_scene_probe(): what a building makes and eats,
    read off an instance with no tile -- exactly what the real probe sees."""
    if self._scene_probed or self.scene is None:
        return
    building = self.scene.instantiate()
    recipe = getattr(building, "recipe", None)
    crafting = building.ns_["Crafting"]
    if recipe is not None and hasattr(building, "_try_post_job"):
        r = crafting.get_recipe(recipe)
        self._items_produced.assign(r.outputs.keys())
        self._items_consumed.assign(r.inputs.keys())
    if hasattr(building, "get_base_yield_types"):
        self._items_produced.assign(building.get_base_yield_types())
    self._display_name = building.get_display_name()
    self.scale_for_tile = 1.0
    self._scene_probed = True


def _scene_exports(path: Path) -> dict:
    """The @export values a building scene sets (FactoryBuilding.recipe)."""
    text = path.read_text(encoding="utf-8")
    body = text.split("[node ", 2)[1]
    return {k: int(v) for k, v in re.findall(r"^(recipe) = (\d+)$", body, re.M)}
