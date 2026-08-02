#!/usr/bin/env python
"""Pacing / economy model for 12 Stinky Starknights.

It plays the game. tools/sim.py runs the real GDScript headless (jobs, walking,
recipes, research, challenges, the cutscene clock -- all the game's own code);
this file is the PLAYER sitting in front of it, plus the report.

The player is deliberately simple and readable, because a balance answer is only
worth as much as the play it assumes:

  * it works ONE objective at a time -- the next thing worth owning -- and saves
    for it, exactly like a player with a shopping list;
  * ONE bill of materials (_retarget) decides everything: what to build, what to
    dig, what to craft and what to tear down. They cannot contradict each other;
  * it OWNS ONLY WHAT IT IS USING. A built, non-automated building whose inputs
    are affordable posts a Job -- the game has no off switch -- so anything the
    bill no longer wants is demolished (instant, full refund) and rebuilt later.
    Nothing here targets walking: keeping fewer standing claims than Starknights
    is just what owning only what you use looks like, and the crew stops
    commuting as a RESULT (~78% walking before this rule, ~25% after);
  * it keeps the Workshop on one standing order, and only re-clicks it when the
    bench goes idle for want of inputs -- a re-click cancels and refunds;
  * idle Starknights dig ahead of need rather than stand around.

What comes out is a timeline of player actions, the cutscene clock, crew
utilisation and -- the number this is all for -- how long the player spent
waiting on each thing.

Usage:
  python balance_model.py [--goal PC_PC] [--amount 1] [--minutes 180]
  python balance_model.py --research "MekaSuit Integration"
  ... [--dt 0.033] [--seed 0] [--no-plots] [-v]

The player's assumptions are the constants at the top of Player -- BANK,
REASSIGN, COPY_LIMIT, GRACE, PATIENCE, DETOUR, STALLED. They are the knobs.
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

import sim
from sim import GAME, Res

CEIL = math.ceil


# ===========================================================================
# What the player knows about the game (derived once, from the loaded source)
# ===========================================================================
class Knowledge:
    def __init__(self, game: sim.Game):
        self.g = game
        self.recipes = list(game.crafting._recipe_map.values())

        # catalog entry <-> building class
        self.cat_of: dict[type, object] = {}
        for entry in game.catalog._catalog:
            self.cat_of[Res.SCENES[entry.scene.path]] = entry

        # what each buildable produces / consumes, per deposit it may stand on
        self.produces: dict[int, list[type]] = {}
        self.recipe_of_class: dict[type, object] = {}
        for cls, entry in self.cat_of.items():
            if hasattr(cls, "_try_consume"):                  # a FactoryBuilding
                recipe = game.crafting.get_recipe(cls.recipe)
                self.recipe_of_class[cls] = recipe
                for item in recipe.outputs:
                    self.produces.setdefault(item, []).append(cls)
            elif hasattr(cls, "get_base_yield_types"):
                for item in self.yields(cls):
                    self.produces.setdefault(item, []).append(cls)

        # item -> the recipe that makes it (the Workshop's only option)
        self.recipe_for: dict[int, object] = {}
        for recipe in self.recipes:
            for item in recipe.outputs:
                self.recipe_for.setdefault(item, recipe)

        self.raws = {item for item in self.produces if item not in self.recipe_for}

    def yields(self, cls: type) -> set[int]:
        """What an extraction site of this class would produce, per allowed
        deposit -- asked of the building itself, so overrides (the coffee farm)
        answer for themselves."""
        out = set()
        entry = self.cat_of[cls]
        for deposit in entry.allowed_deposits:
            probe = cls()
            probe.tile = _FakeTile(deposit)
            out |= {i for i in probe.get_base_yield_types() if i}
        return out

    def deposits_for(self, cls: type, item: int) -> list[int]:
        """The deposits a site of `cls` must stand on to yield `item`."""
        out = []
        for deposit in self.cat_of[cls].allowed_deposits:
            probe = cls()
            probe.tile = _FakeTile(deposit)
            if item in probe.get_base_yield_types():
                out.append(deposit)
        return out

    # -- what the goal needs, all the way down --------------------------------
    def closure(self, seed: set[int]) -> set[int]:
        """Every item on the way to `seed`: recipe inputs, the build cost of the
        buildings that make them, and the research that unlocks them."""
        items = set(seed)
        while True:
            grown = set(items)
            for item in items:
                recipe = self.recipe_for.get(item)
                if recipe:
                    grown |= set(recipe.inputs)
                for cls in self.produces.get(item, ()):
                    grown |= set(self.cat_of[cls].cost)
            for research in self.g.research._items:   # research is bought out of
                if research.state != research.State.COMPLETED:
                    grown |= set(research.cost)          # the same economy
            if grown == items:
                return items
            items = grown


@dataclass
class _FakeTile:
    deposit: int


# ===========================================================================
# The player
# ===========================================================================
@dataclass
class Objective:
    kind: str                      # build | research | goal
    label: str
    cost: dict
    place: object = None           # (catalog entry, tile)
    research: object = None        # (ResearchItem, building)
    started: float = 0.0


class Player:
    BANK = 100                     # how far ahead of need a deposit is worth working
    REASSIGN = 30.0                # how often the crew is re-pointed at deposits
    COPY_LIMIT = 3                 # copies of one building before upgrades win
    GRACE = 120.0                  # how long something may sit unwanted before it goes

    def __init__(self, game: sim.Game, know: Knowledge, goal: int, amount: int,
                 research_goal=None, verbose: bool = False):
        self.g, self.k = game, know
        self.goal, self.amount = goal, amount
        self.research_goal = research_goal        # a ResearchItem to finish instead
        self.verbose = verbose
        seed = {goal} if goal else set()
        for item in self._chain(research_goal):
            seed |= set(item.cost)
        self.wanted = know.closure(seed)
        self.objective: Objective | None = None
        self.waits: dict[str, float] = {}
        self.order = None      # (recipe, target, item, since, made) in progress
        self.blocked: dict[str, float] = {}     # label -> when to consider it again
        self._shortfall, self._progress_at = math.inf, 0.0
        self._harvest_at = -math.inf
        self._order_unwanted = self._order_idle = 0.0
        self._unwanted_since: dict[int, float] = {}   # building id -> when it went idle
        self.targets: dict[int, int] = {}       # item -> how much the goal still needs
        self.demand: set[int] = set()           # the items in targets we are short of
        self.done_at: float | None = None

    # -- main entry ---------------------------------------------------------
    def tick(self):
        if self.done_at is None and self._reached():
            self.done_at = self.g.now
        self._retarget()
        self._choose_objective()
        self._shed()
        self._harvest()
        self._craft()

    def _retarget(self):
        """How much of everything the colony is still short of.

        ONE map drives all four decisions -- what to build, what to harvest, what
        to craft and what to tear down -- so they cannot contradict each other.
        It is the goal's whole bill of materials, plus whatever the objective in
        hand needs on top of it, minus what is already in the pile."""
        targets = self._requirements(self._goal_cost())
        if self.objective is not None:
            for item, qty in self._requirements(self.objective.cost).items():
                targets[item] = max(targets.get(item, 0), qty)
        # When the goal is story-locked there is nothing to buy that unlocks it
        # directly -- the cutscene chain is watching for something to be MADE
        # (the PC needs an Industrial Computer Module to have been seen first).
        # So make one of everything the colony has never seen and keep playing,
        # which is what a player does when the story is holding them up.
        if self._story_locked():
            for item in self.wanted:
                if not self.g.stockpile.is_seen(item):
                    targets[item] = max(targets.get(item, 0), 1)

        self.targets = targets
        self.demand = {i for i, q in targets.items()
                       if self.g.stockpile.get_amount(i) < q}

    def _story_locked(self) -> bool:
        """Is the goal itself waiting on a cutscene?"""
        if self.research_goal is not None:
            return False
        return self.g.stockpile.is_unavailable_story_item(self.goal)

    def _goal_cost(self) -> dict:
        """The whole bill still outstanding: the goal itself, and the buildings
        the goal's chain still needs raising.

        Leaving the build costs out was a real bug -- between two objectives the
        colony believed it needed nothing, switched the deposits off and idled."""
        if self.research_goal is None:
            cost = {self.goal: self.amount}
        else:
            cost = {}
            for item in self._chain(self.research_goal):
                if item.state != item.State.COMPLETED:
                    for res, qty in item.cost.items():
                        cost[res] = cost.get(res, 0) + qty

        for item in list(self._requirements(cost)):
            if self._producer_coming(item):
                continue
            for cls in self.k.produces.get(item, ()):
                for res, qty in self.k.cat_of[cls].cost.items():
                    cost[res] = cost.get(res, 0) + qty
                break                      # one producer per item is enough
        return cost

    # -- objectives ----------------------------------------------------------
    def _choose_objective(self):
        """Pick something to save up for -- and then STICK TO IT.

        Re-deciding every second is not how anyone plays, and it thrashes: the
        Workshop order that feeds an objective gets cancelled and re-issued each
        time the list reshuffles. The objective is only dropped once it is bought
        or has become impossible."""
        current = self.objective
        # the goal is never something to "save up for" exclusively -- the colony
        # keeps buying and building while the last parts come together, and the
        # tier order puts anything else first anyway
        if current is not None and current.kind != "goal" and not self._stale(current):
            if self._afford(current.cost):
                self._execute(current)
                self.objective = None
            elif self._patience(current):
                self.waits[current.label] = self.waits.get(current.label, 0.0) + POLICY_STEP
                return
            else:
                # nothing has moved for a long time -- something else is eating the
                # inputs. Shelve it and go do something that is actually possible.
                self.blocked[current.label] = self.g.now + self.PATIENCE
                self.objective = None
            if self.objective is not None:
                return

        self.objective = self._next_objective()
        if self.objective is not None:
            self.objective.started = self.g.now
            self._shortfall, self._progress_at = math.inf, self.g.now

    PATIENCE = 600.0               # seconds of no progress before giving up on a buy

    def _patience(self, obj: Objective) -> bool:
        """Is this still worth waiting for?

        The goal always is -- there is nothing better to do than finish it, and
        walking away mid-assembly cancels a two-minute craft and refunds every
        part. Everything else has to keep shrinking its bill or it gets shelved."""
        if obj.kind == "goal":
            return True
        short = sum(max(0, n - self.g.stockpile.get_amount(i)) for i, n in obj.cost.items())
        if short < self._shortfall:
            self._shortfall, self._progress_at = short, self.g.now
        return self.g.now - self._progress_at < self.PATIENCE

    def _stale(self, obj: Objective) -> bool:
        if obj.kind == "build":
            entry, tile = obj.place
            return tile.building is not None or entry not in self.g.catalog.get_unlocked_buildings()
        if obj.kind == "research":
            item, _building = obj.research
            return item.state != item.State.AVAILABLE
        return self._reached()

    # The shopping list, in tiers. Within a tier the cheapest ACHIEVABLE thing
    # wins, where "cheapest" is seconds of colony work still owed for it (_effort)
    # and "achievable" means nothing in the bill is impossible yet -- which is what
    # stops the list saving forever for a Pumping Station it cannot reach.
    WAREHOUSE, PRODUCER, CAPABILITY, AUTOMATION, EXPAND, GOAL, UPGRADE = range(7)

    def _next_objective(self) -> Objective | None:
        stock = self.g.stockpile
        unlocked = {Res.SCENES[e.scene.path]: e
                    for e in self.g.catalog.get_unlocked_buildings()}
        built = self._built()
        starving = set(self._starving())
        bottleneck = {cls for item in starving for cls in self.k.produces.get(item, ())}
        out: list[tuple[int, float, Objective]] = []

        def offer(tier: int, obj: Objective | None):
            if obj is not None and self.blocked.get(obj.label, 0.0) <= self.g.now:
                out.append((tier, self._effort(obj.cost), obj))

        # the Warehouse: the story asks for it and the crew-speed tree lives there
        warehouse = self.g.building_classes["Warehouse"]
        if not built.get("Warehouse"):
            offer(self.WAREHOUSE, self._build_objective(warehouse, unlocked))

        # a producer for anything the objective is short of that nothing makes
        # yet, rawest first. Demand-driven, so it agrees with _shed(): the colony
        # builds what it is working towards and tears down what it is not.
        # A deposit the crew can already work by hand only earns a site when the
        # colony is actually SHORT of it -- otherwise the shopping list insists on
        # an 800-petrochemical Logging Camp to replace four lumber tiles.
        for item in self._by_depth():
            if item not in self.demand or self._producer_coming(item):
                continue
            if (item in self.k.raws and self._obtainable(item)
                    and stock.get_amount(item) >= self.BANK / 2):
                continue           # hand-harvest is keeping up; a site can wait
            for cls in self.k.produces.get(item, ()):
                offer(self.PRODUCER, self._build_objective(cls, unlocked, item))

        # the Workshop capability a wanted, factory-less recipe needs
        for obj in self._capability_objectives():
            offer(self.CAPABILITY, obj)

        # automation, once every Starknight is tied to a building
        if self._manned() >= len(self.g.knights):
            for obj in self._research_objectives(lambda r, b: r.display_name == "Automation"):
                offer(self.AUTOMATION, obj)

        # more of, or better at, whatever the current craft is starving on
        for cls in bottleneck:
            if 0 < built.get(cls.__name__, 0) < self.COPY_LIMIT:
                offer(self.EXPAND, self._build_objective(cls, unlocked))
        for obj in self._research_objectives(
                lambda r, b: r.display_name != "Automation" and type(b) in bottleneck):
            offer(self.EXPAND, obj)

        # the goal itself: an item to assemble, or the next step of a research chain
        if self.research_goal is not None:
            offer(self.GOAL, self._chain_objective())
        elif stock.get_amount(self.goal) < self.amount:
            offer(self.GOAL, Objective("goal", f"assemble {self._name(self.goal)}",
                                       {self.goal: self.amount}))

        # anything else worth researching
        for obj in self._research_objectives(lambda r, b: r.display_name != "Automation"):
            offer(self.UPGRADE, obj)

        reachable = [c for c in out if c[1] < math.inf]
        # nothing is worth more work than finishing: the crew-speed tree wants
        # 12,000 Jelly Coffee, which is not a shortcut to anything
        finish = min((c[1] for c in reachable if c[0] == self.GOAL), default=math.inf)
        if math.isfinite(finish):
            reachable = [c for c in reachable if c[1] <= finish]
        if not reachable:                    # nothing is fully reachable: get closer
            reachable = out
        if not reachable:
            return None
        tier, effort, best = min(reachable, key=lambda c: (c[0], c[1]))

        # 800 bricks away? Then a cheap upgrade to whatever makes bricks comes
        # first. Anything that feeds the chosen objective and costs a fraction of
        # it is bought on the way -- which is the whole point of the upgrade tree.
        wants = set(self._requirements(best.cost))
        helpers = [c for c in reachable
                   if c[2] is not best and c[1] < self.DETOUR * effort
                   and self._helps(c[2], wants)]
        return min(helpers, key=lambda c: c[1])[2] if helpers else best

    DETOUR = 0.3                   # a helper is only worth it at this fraction of the cost

    # -- a research chain as the goal (the "how long to MekaSuit?" benchmark) ---
    def _chain(self, target) -> list:
        """`target` and its prerequisites, prerequisites first."""
        out: list = []

        def visit(item):
            if item is None or item in out:
                return
            for prereq in item.prerequisites:
                visit(prereq)
            out.append(item)

        visit(target)
        return out

    def _chain_objective(self) -> Objective | None:
        """The next uncompleted step of the goal chain that can be started now."""
        for item in self._chain(self.research_goal):
            if item.state == item.State.COMPLETED:
                continue
            if item.state != item.State.AVAILABLE:
                return None                    # its prerequisites are still running
            building = next((b for b in self._buildings() if type(b) is item.research_at),
                            None)
            if building is None:
                return None                    # the building it lives in is not up yet
            return Objective("research",
                             f"research {item.display_name} @ {building.get_display_name()}",
                             dict(item.cost), research=(item, building))
        return None

    def _reached(self) -> bool:
        if self.research_goal is not None:
            return self.research_goal.state == self.research_goal.State.COMPLETED
        return self.g.stockpile.get_amount(self.goal) >= self.amount

    def _helps(self, obj: Objective, wants: set[int]) -> bool:
        """Would owning this make the objective arrive sooner?"""
        if obj.kind == "build":
            entry, _tile = obj.place
            return bool(self._outputs(Res.SCENES[entry.scene.path]) & wants)
        if obj.kind == "research":
            _item, building = obj.research
            return bool(self._outputs(type(building)) & wants)
        return False

    def _outputs(self, cls: type) -> set[int]:
        if cls in self.k.recipe_of_class:
            return set(self.k.recipe_of_class[cls].outputs)
        if hasattr(cls, "get_base_yield_types"):
            return self.k.yields(cls)
        return set()

    def _producer_coming(self, item: int) -> bool:
        """A producer that exists OR is still being built -- one is enough; a
        second copy is a capacity decision, not a structural one."""
        if self._factory_for(item):
            return True
        for tile in self.g.tiles.values():
            b = tile.building
            if b is None or b.is_constructed():
                continue
            if hasattr(b, "get_base_yield_types"):
                if item in b.get_base_yield_types():   # what THIS tile would yield
                    return True
            elif item in self._outputs(type(b)):
                return True
        return False

    def _effort(self, cost: dict) -> float:
        """Roughly how many SECONDS of colony work `cost` still needs, or INF when
        something in it cannot be made at all yet (no capability, no factory, no
        reachable deposit).

        Crude on purpose -- it only has to rank shopping-list entries. What it
        must get right is that a hand-crafted batch costs its full recipe work at
        the one bench, which is exactly why building the factory first pays."""
        speedup = self.g.building_classes["Sawmill"].BASE_WORK_SPEEDUP

        def item_effort(item, qty, seen):
            short = qty - self.g.stockpile.get_amount(item)
            if short <= 0:
                return 0.0
            if item in seen:
                return math.inf
            if item in self.k.raws:
                rate = self._dig_rate(item)
                return short / rate if rate else math.inf
            recipe = self.k.recipe_for.get(item)
            if recipe is None:
                return math.inf
            factory = self._factory_for(item)
            if not factory and not self._craftable(recipe):
                return math.inf
            runs = CEIL(short / recipe.outputs[item])
            work = runs * recipe.work / (speedup if factory else 1.0)
            return work + sum(item_effort(i, n * runs, seen | {item})
                              for i, n in recipe.inputs.items())

        return sum(item_effort(i, q, frozenset()) for i, q in cost.items())

    def _dig_rate(self, item: int) -> float:
        """Units per second the colony can pull out of the ground: one per second
        per worked tile (HexTile.HARVEST_DURATION), or the faster site if one
        stands on the deposit."""
        tile_cls = type(self.g.workshop.tile)
        rate = 0.0
        for tile in self.g.tiles.values():
            if tile.deposit != item:
                continue
            if tile.building is not None:
                site = tile.building
                if hasattr(site, "_will_harvest") and site.is_constructed():
                    rate += site._get_base_yield_amount() * site._get_yield_scale() \
                        / site._duration()
            elif tile.workable:
                rate += tile_cls.HARVEST_AMOUNT / tile_cls.HARVEST_DURATION
        return rate

    def _obtainable(self, item: int) -> bool:
        """A raw is only real if something can dig it: a free workable tile, or a
        site already standing on its deposit."""
        if self._factory_for(item):
            return True
        return any(t.workable and t.building is None and t.deposit == item
                   for t in self.g.tiles.values())

    def _build_objective(self, cls: type, unlocked: dict, item: int | None = None):
        entry = unlocked.get(cls)
        if entry is None:
            return None                                   # story-locked, or unknown
        deposits = (self.k.deposits_for(cls, item) if item is not None
                    and hasattr(cls, "get_base_yield_types") else entry.allowed_deposits)
        tile = self._free_tile(entry, deposits)
        if tile is None:
            return None
        return Objective("build", f"build {entry.get_display_name()}"
                         + (f" ({self._name(item)})" if item and len(deposits) > 1 else ""),
                         dict(entry.cost), place=(entry, tile))

    def _capability_objectives(self):
        """Workshop research that unlocks a wanted recipe no factory can run."""
        need = set()
        for item in self.wanted:
            recipe = self.k.recipe_for.get(item)
            if recipe is None or self._factory_for(item):
                continue
            need |= {c for c in recipe.needs_capabilities
                     if c not in self.g.building_classes["Workshop"].capabilities}
        if not need:
            return []
        return self._research_objectives(
            lambda r, b: type(b).__name__ == "Workshop" and bool(self._grants(r) & need))

    def _grants(self, research) -> set:
        """The capability a Workshop research adds (from its on_complete)."""
        return CAPABILITY_OF.get(research.display_name, set())

    def _research_objectives(self, accept) -> list[Objective]:
        """Every research the player could actually click right now: Research.
        available_for() shows one item per slot per building, which is the real
        constraint on what a tree offers next."""
        out = []
        for building in self._buildings():
            for item in self.g.research.available_for(building):
                if item.state != item.State.AVAILABLE or not accept(item, building):
                    continue
                if not self._useful(item, building):
                    continue
                out.append(Objective(
                    "research",
                    f"research {item.display_name} @ {building.get_display_name()}",
                    dict(item.cost), research=(item, building)))
        return out

    def _useful(self, research, building) -> bool:
        """Skip upgrades on a building whose output nothing on the path wants, and
        the crew-speed tree until the colony is actually walking a lot."""
        if research.display_name in CAPABILITY_OF or research.display_name == "Automation":
            return True
        cls = type(building)
        if cls in self.k.recipe_of_class:
            outputs = set(self.k.recipe_of_class[cls].outputs)
        elif hasattr(cls, "get_base_yield_types"):
            outputs = self.k.yields(cls)
        else:
            return True                     # the Workshop and the Warehouse trees
        return bool(outputs & self.wanted)

    # -- execution -----------------------------------------------------------
    def _execute(self, obj: Objective):
        if obj.kind == "build":
            entry, tile = obj.place
            if tile.building is None:
                entry.try_place_on(tile)
        elif obj.kind == "research":
            item, building = obj.research
            self.g.research.start_research(item, building)

    # -- shedding ------------------------------------------------------------
    def _shed(self):
        """Tear down what the colony is no longer working towards.

        A built, non-automated building whose inputs are affordable POSTS A JOB --
        the game has no way to switch one off. So every one of them is a standing
        claim on a Starknight, and a knight answering a claim it did not need to
        walks there and back for nothing. Demolition is instant, posts no Job and
        refunds the whole build cost (Building._construction_aborted), so a
        building that has stopped serving the current objective is pure loss and
        goes. It gets rebuilt (for the same materials) when it is wanted again --
        which is exactly the demolish/rebuild-after-automation pattern real play
        shows.

        Nothing here is aimed at "walking" as such: fewer standing claims than
        Starknights is simply what a colony that only owns what it needs looks
        like, and the walking falls out of it."""
        for tile in list(self.g.tiles.values()):
            building = tile.building
            if building is None or not building.is_constructed():
                continue
            if not building.can_demolish() or not hasattr(building, "_is_automated"):
                continue                       # the Workshop, the Warehouse: no Job
            if building._is_automated():
                continue                       # runs on a timer, costs no Starknight
            key = id(building)
            if self._outputs_of(building) & self.demand:
                self._unwanted_since.pop(key, None)
                continue
            since = self._unwanted_since.setdefault(key, self.g.now)
            if self.g.now - since >= self.GRACE:
                self._unwanted_since.pop(key, None)
                building.demolish()

    def _outputs_of(self, building) -> set[int]:
        """What this particular building makes -- an extraction site answers for
        the deposit it actually stands on."""
        if hasattr(building, "get_base_yield_types"):
            return set(building.get_base_yield_types())
        return self._outputs(type(building))

    # -- harvesting ----------------------------------------------------------
    def _harvest(self):
        """Work the nearest tiles of what the current objective is short of.

        Never more tiles than Starknights: the JobManager hands every posted job
        to its closest IDLE knight, so switching on the whole map at once just
        scatters the crew across it (the game's own 'use them optimally' nag).
        Spare capacity goes to the next-nearest wanted deposit -- banking ahead
        costs nothing, harvest is the lowest priority in the game."""
        if self.g.now - self._harvest_at < self.REASSIGN:
            return                    # re-assigning the crew every second is churn
        self._harvest_at = self.g.now
        stock, home = self.g.stockpile, self.g.workshop.tile
        need = {i: q for i, q in self.targets.items() if i in self.k.raws}

        def rank(tile):
            """Short of it first, then already-banked deposits, nearest first --
            a knight with nothing better to do may as well dig ahead of need."""
            short = stock.get_amount(tile.deposit) < need.get(tile.deposit, 0) + self.BANK
            return (tile.deposit not in need, not short,
                    self.g.world.walk_length(home, tile))

        candidates = sorted((t for t in self.g.tiles.values()
                             if t.workable and t.building is None
                             and t.deposit in self.wanted), key=rank)
        # leave a Starknight for every building that is holding a Job: a knight on
        # a one-second harvest job spends most of its time walking back to it
        budget = max(1, len(self.g.knights) - self._manned())
        on = set(id(t) for t in candidates[:budget])
        for tile in self.g.tiles.values():
            if tile.workable and tile.building is None:
                tile.set_harvesting(id(tile) in on)

    # -- the Workshop --------------------------------------------------------
    STALLED = 45.0                 # give up on an order that has made nothing for this long

    def _craft(self):
        """One order at a time, and let it RUN.

        The bench is a single job: re-picking a target every second would cancel
        the order (and refund its inputs) over and over, which is neither what a
        player does nor free. A standing order is replaced when it is finished,
        when what it makes is no longer wanted, when the objective moves on, or
        when it has stopped producing because its own inputs dried up."""
        workshop, stock = self.g.workshop, self.g.stockpile
        # what the OBJECTIVE needs, not the colony-wide bill: the bench is one
        # job and it belongs to the thing being saved for
        focus = self._requirements(self.objective.cost) if self.objective else {}
        if self.order is not None:
            recipe, amount, item, since, made = self.order
            # "no longer wanted" needs the same patience as everything else: the
            # numbers flicker as stock crosses a target, and re-issuing the order
            # on every flicker cancels and refunds it for nothing
            if stock.get_amount(item) < focus.get(item, 0) or item in self.demand:
                self._order_unwanted = self.g.now
            # An order is STALLED when the bench is standing idle for want of its
            # inputs -- not merely when nothing has come out yet. Assembling the
            # PC is two minutes of work with its parts already consumed, and
            # judging that by output would cancel it every time.
            if self.g.workshop._order_job is not None:
                self._order_idle = self.g.now
            done = (stock.get_amount(item) >= amount
                    or self.g.now - self._order_unwanted >= self.STALLED)
            if not done and self.g.now - self._order_idle < self.STALLED:
                return

        target = self._craft_target(focus)
        if target is None:
            if self.order is not None and workshop.order is not None:
                workshop.clear_order()
            self.order = None
            return
        recipe, amount, item = target
        if workshop.order is recipe and workshop.order_target == amount:
            return                     # already on the bench: re-clicking cancels it
        self.order = (recipe, amount, item, self.g.now, stock.get_cumulative(item))
        self._order_unwanted = self._order_idle = self.g.now
        workshop.apply_order(recipe, workshop.Repeat.UNTIL, amount)

    def _craft_target(self, need: dict):
        """The deepest thing the bench can make that the objective is short of."""
        best = None
        for item, qty in need.items():
            if self.g.stockpile.get_amount(item) >= qty or item in self.k.raws:
                continue
            if self._factory_for(item):
                continue                       # a building already makes this
            recipe = self.k.recipe_for.get(item)
            if recipe is None or not self._craftable(recipe):
                continue
            if any(self.g.stockpile.get_amount(i) < n for i, n in recipe.inputs.items()):
                continue                       # its own ingredients are not in yet
            depth = self._depth(item)
            if best is None or depth < best[0]:
                best = (depth, (recipe, qty, item))
        return best[1] if best else None

    def _requirements(self, cost: dict) -> dict[int, int]:
        """`cost` plus every intermediate it implies, as absolute stock targets --
        200 planks for the build AND the 10 the mechanical components will eat."""
        need: dict[int, int] = {}

        def walk(item, qty, seen):
            need[item] = need.get(item, 0) + qty
            short = need[item] - self.g.stockpile.get_amount(item)
            if short <= 0 or item in seen or item in self.k.raws:
                return
            recipe = self.k.recipe_for.get(item)
            if recipe is None:
                return
            runs = CEIL(short / recipe.outputs[item])
            for ingredient, n in recipe.inputs.items():
                walk(ingredient, n * runs, seen | {item})

        for item, qty in cost.items():
            walk(item, qty, frozenset())
        return need

    def _depth(self, item: int, seen=()) -> int:
        recipe = self.k.recipe_for.get(item)
        if recipe is None or item in seen:
            return 0
        return 1 + max([self._depth(i, tuple(seen) + (item,))
                        for i in recipe.inputs] or [0])

    def _craftable(self, recipe) -> bool:
        """What the bench would actually offer -- Crafting.recipes_for_workshop():
        the capabilities, and OUTPUTS that are not story-locked. Inputs are not
        checked, so a part whose own challenge has already completed (the 9th PC
        fan) can still be consumed; only a challenge changing under a STANDING
        order cancels it (Workshop._on_challenge_updated)."""
        workshop = self.g.building_classes["Workshop"]
        if any(c not in workshop.capabilities for c in recipe.needs_capabilities):
            return False
        return not any(self.g.stockpile.is_unavailable_story_item(i)
                       for i in recipe.outputs)

    # -- small helpers --------------------------------------------------------
    def _name(self, item):
        return self.g.item_name.get(item, str(item))

    def _buildings(self):
        seen, out = set(), []
        for tile in self.g.tiles.values():
            b = tile.building
            if b is not None and b.is_constructed() and type(b).__name__ not in seen:
                seen.add(type(b).__name__)
                out.append(b)
        return out

    def _built(self) -> dict[str, int]:
        out: dict[str, int] = {}
        for tile in self.g.tiles.values():
            if tile.building is not None:
                name = type(tile.building).__name__
                out[name] = out.get(name, 0) + 1
        return out

    def _manned(self) -> int:
        """Standing claims on the crew: non-automated buildings with a Job posted.

        Not every built building costs a Starknight -- one that cannot afford its
        inputs posts nothing and is free to own. `_has_active_job` is the game's
        own flag for "this building is holding a Job right now", which is exactly
        the drain the crew feels."""
        total = 0
        for tile in self.g.tiles.values():
            b = tile.building
            if b is None or not b.is_constructed() or not hasattr(b, "_is_automated"):
                continue
            if not b._is_automated() and b._has_active_job:
                total += 1
        return total

    def _factory_for(self, item: int):
        for tile in self.g.tiles.values():
            b = tile.building
            if b is None or not b.is_constructed():
                continue
            cls = type(b)
            if cls in self.k.recipe_of_class and item in self.k.recipe_of_class[cls].outputs:
                return b
            if hasattr(b, "get_base_yield_types") and item in b.get_base_yield_types():
                return b
        return None

    def _free_tile(self, entry, deposits):
        home = self.g.workshop.tile
        best, best_d = None, math.inf
        for tile in self.g.tiles.values():
            if tile.building is not None or not tile.walkable or tile.deposit not in deposits:
                continue
            d = self.g.world.walk_length(home, tile)
            if d < best_d:
                best, best_d = tile, d
        return best

    def _by_depth(self):
        """Wanted items, rawest first: a producer is only worth building once its
        inputs exist, and this is the order that falls out of the recipe tree."""
        depth: dict[int, int] = {}

        def rank(item, seen=()):
            if item in depth:
                return depth[item]
            if item in seen:
                return 0
            recipe = self.k.recipe_for.get(item)
            d = 0 if recipe is None else 1 + max(
                [rank(i, tuple(seen) + (item,)) for i in recipe.inputs] or [0])
            depth[item] = d
            return d

        return sorted(self.wanted, key=rank)

    def _starving(self):
        """Items the current craft cannot get enough of."""
        obj = self.objective
        if obj is None:
            return []
        return [i for i, n in sorted(obj.cost.items(), key=lambda kv: -kv[1])
                if self.g.stockpile.get_amount(i) < n]

    def _afford(self, cost) -> bool:
        return all(self.g.stockpile.get_amount(i) >= n for i, n in cost.items())


# Workshop research -> the capability it grants (Workshop.gd's on_complete).
CAPABILITY_OF: dict[str, set] = {}


def _read_capabilities(game: sim.Game):
    """Which Workshop research adds which capability, read from Workshop.gd."""
    caps = game.crafting.Capabilities
    text = (GAME / "objects/buildings/Workshop.gd").read_text(encoding="utf-8")
    name = None
    for line in text.splitlines():
        m = re.search(r'(\w+)\.display_name\s*=\s*"([^"]*)"', line)
        if m:
            name = (m.group(1), m.group(2))
        m = re.search(r"capabilities\.append\(Crafting\.Capabilities\.(\w+)\)", line)
        if m and name:
            CAPABILITY_OF[name[1]] = {getattr(caps, m.group(1))}


# ===========================================================================
# Running
# ===========================================================================
POLICY_STEP = 1.0                  # the player looks at the screen once a second


@dataclass
class Trace:
    t: list[float] = field(default_factory=list)
    working: list[int] = field(default_factory=list)
    walking: list[int] = field(default_factory=list)
    idle: list[int] = field(default_factory=list)
    buildings: list[int] = field(default_factory=list)
    stock: dict[int, list[int]] = field(default_factory=dict)


def play(goal: str, amount: int, minutes: float, dt: float, seed: int,
         verbose: bool = False, research: str | None = None):
    """Run one playthrough. `goal` is an ItemType name, or use `research` to race
    to a named research instead."""
    game = sim.Game(dt=dt, seed=seed)
    game.register_all_research()
    _read_capabilities(game)
    know = Knowledge(game)

    target, item = None, None
    if research:
        # every research item exists from the start of the game; the tree it lives
        # in is registered when its building is first raised, so look it up there
        target = next((r for r in game.research._items
                       if r.display_name.lower() == research.lower()), None)
        if target is None:
            raise LookupError(f"unknown research '{research}'. known: " + ", ".join(
                sorted({r.display_name for r in game.research._items})))
    else:
        item = getattr(game.items, goal.upper(), None)
        if not item:
            raise LookupError(f"unknown item '{goal}'. known: "
                              + ", ".join(game.items.keys()))
        TRACKED[:] = [game.items.RAW_TITANIUM, game.items.BRICKS,
                      game.items.MECHANICAL_COMPONENTS, item]
    player = Player(game, know, item, amount, target, verbose)
    trace = Trace()

    steps = int(minutes * 60 / dt)
    next_policy = next_sample = 0.0
    for _ in range(steps):
        game.tick()
        if game.now >= next_policy:
            next_policy += POLICY_STEP
            player.tick()
            if verbose and player.objective:
                print(f"  {game.now/60:6.1f}m  {player.objective.label}")
        if game.now >= next_sample:
            next_sample += 5.0
            _sample(game, player, trace)
        if player.done_at is not None:
            break
    return game, know, player, trace


def _sample(game: sim.Game, player: Player, trace: Trace):
    states = [k._state for k in game.knights]
    State = type(game.knights[0]).State
    trace.t.append(game.now)
    trace.working.append(sum(s == State.WORKING for s in states))
    trace.walking.append(sum(s == State.MOVING for s in states))
    trace.idle.append(sum(s == State.IDLE for s in states))
    trace.buildings.append(sum(1 for t in game.tiles.values() if t.building is not None))
    for item in TRACKED:
        trace.stock.setdefault(item, []).append(game.stockpile.get_amount(item))


TRACKED: list[int] = []


# ===========================================================================
# Report
# ===========================================================================
def fmt(seconds: float) -> str:
    return f"{seconds / 60:6.1f}m"


def report(game: sim.Game, know: Knowledge, player: Player, trace: Trace, dt: float):
    log = game.log.entries
    actions = [e for e in log if e["kind"] != "harvest"]
    total = player.done_at or game.now

    print("=" * 78)
    print("  12 STINKY STARKNIGHTS -- pacing model (a simulated playthrough)")
    print("=" * 78)
    print(f"  map {len(game.tiles)} tiles, "
          f"{sum(1 for t in game.tiles.values() if t.walkable)} walkable, "
          f"{sum(1 for t in game.tiles.values() if t.workable)} workable deposits | "
          f"crew {len(game.knights)}")
    goal_text = (f"finish the {player.research_goal.display_name} research"
                 if player.research_goal is not None
                 else f"{player.amount} x {game.item_name[player.goal]}")
    print(f"  goal: {goal_text} | "
          f"{len(know.recipes)} recipes | {len(game.catalog._catalog)} buildables | "
          f"{len(game.research._items)} research items | dt {dt:.3f}s")
    if player.done_at:
        print(f"  GOAL REACHED at {fmt(player.done_at)}")
    else:
        print(f"  GOAL NOT REACHED in {fmt(game.now)} -- "
              f"stuck on: {player.objective.label if player.objective else 'nothing to do'}")
    print()

    print("-" * 78)
    print("  PLAYER ACTIONS  (the game's own ActivityLog)")
    print("-" * 78)
    for e in actions:
        detail = f"  ({e['detail']})" if e["detail"] else ""
        print(f"    {fmt(e['seconds'])}  {e['kind']:<9} {e['name']}{detail}")
    if not actions:
        print("    (none)")
    print()

    print("-" * 78)
    print("  STORY CLOCK  (Story.gd; cutscenes gate every challenge)")
    print("-" * 78)
    for cut in game.cutscenes.played:
        print(f"    {fmt(cut.start)} -> {fmt(cut.end)}  {cut.scene.var_name}")
    pending = [c.var_name for c in game.story._locked_cutscenes]
    if pending:
        print(f"    never fired: {', '.join(pending)}")
    print()

    print("-" * 78)
    print("  CHALLENGES  (a locked item cannot be crafted and hides its buildings)")
    print("-" * 78)
    for item, challenge in game.stockpile._challenges.items():
        state = ["LOCKED", "ACTIVE", "COMPLETED"][challenge.state]
        limit = challenge.get_limit()
        print(f"    {game.item_name[item]:<28} {state:<10} "
              f"made {game.stockpile.get_cumulative(item)}"
              f"{f' of {limit}' if limit else ''}")
    print()

    print("-" * 78)
    print("  ACTIVITY  (density of player actions -- the design goal is early-heavy)")
    print("-" * 78)
    half = total / 2
    early = sum(1 for e in actions if e["seconds"] < half)
    kinds: dict[str, int] = {}
    for e in actions:
        kinds[e["kind"]] = kinds.get(e["kind"], 0) + 1
    print("    " + ", ".join(f"{n} {k}" for k, n in sorted(kinds.items())) +
          f"  ({len(actions)} actions)")
    print(f"    density: first half {early / max(half / 60, 1e-9):5.2f}/min"
          f"   ->   second half {(len(actions) - early) / max(half / 60, 1e-9):5.2f}/min")
    print(f"    plus {sum(1 for e in log if e['kind'] == 'harvest')} deposit "
          f"on/off toggles (the crew being re-pointed at deposits)")
    if trace.t:
        n = len(game.knights)
        print(f"    crew: {sum(trace.working) / len(trace.t) / n:5.1%} working, "
              f"{sum(trace.walking) / len(trace.t) / n:5.1%} walking, "
              f"{sum(trace.idle) / len(trace.t) / n:5.1%} idle "
              f"(walking is the cost of spreading out)")
    print()

    print("-" * 78)
    print("  WAITING  (wall clock the player spent saving up for one thing)")
    print("-" * 78)
    for label, seconds in sorted(player.waits.items(), key=lambda kv: -kv[1])[:15]:
        print(f"    {fmt(seconds)}  {label}  ({seconds / max(total, 1) * 100:.0f}% of the run)")
    print()

    print("-" * 78)
    print("  PRODUCTION  (cumulative, and what is left over)")
    print("-" * 78)
    for item in game.items.values():
        if not item:
            continue
        made = game.stockpile.get_cumulative(item)
        if made:
            print(f"    {game.item_name[item]:<28} made {made:>7}   "
                  f"left {game.stockpile.get_amount(item):>7}")
    print("=" * 78)


def plots(game: sim.Game, player: Player, trace: Trace, out: Path):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    colours = {"build": "#23deff", "research": "#b060e0", "wresearch": "#e05a8a",
               "upgrade": "#d8b020", "automate": "#40c060", "craft": "#e0782a",
               "demolish": "#d05050", "harvest": "#888888"}
    log = game.log.entries
    actions = [e for e in log if e["kind"] != "harvest"]
    toggles = [e for e in log if e["kind"] == "harvest"]
    rows: dict[str, list] = {}
    for e in log:
        # every tile of one deposit shares a row: which of the four clay tiles is
        # being worked says nothing, when clay is being worked says everything
        label = (f"harvest: {e['name']}" if e["kind"] == "harvest"
                 else f"{e['kind']}: {e['name']}")
        rows.setdefault(label, []).append(e)
    order = sorted(rows, key=lambda r: min(e["seconds"] for e in rows[r]))

    fig, (ax1, ax2, ax3) = plt.subplots(
        3, 1, figsize=(11, max(6.0, 0.28 * len(order) + 6.0)),
        gridspec_kw={"height_ratios": [3, 1, 1]})

    for y, row in enumerate(order):
        py = len(order) - 1 - y
        xs = [e["seconds"] / 60 for e in rows[row]]
        if len(xs) > 1:
            ax1.hlines(py, min(xs), max(xs), color="#dddddd", lw=1, zorder=1)
        # a harvest toggle is on (filled) or off (hollow); everything else is a
        # one-off click
        faces = ["none" if e["detail"] == "off" else colours.get(e["kind"], "#333")
                 for e in rows[row]]
        ax1.scatter(xs, [py] * len(xs), s=30, zorder=3, facecolors=faces,
                    edgecolors=[colours.get(e["kind"], "#333") for e in rows[row]],
                    linewidths=1.0)
    ax1.set_yticks(range(len(order)))
    ax1.set_yticklabels(list(reversed(order)), fontsize=7)
    ax1.set_ylim(-0.6, len(order) - 0.4)
    goal_text = (player.research_goal.display_name if player.research_goal is not None
                 else f"{player.amount} x {game.item_name[player.goal]}")
    ax1.set_title(f"Playthrough: {goal_text}"
                  + (f" in {player.done_at / 60:.0f} min" if player.done_at else " (unfinished)"))
    ax1.grid(True, axis="x", alpha=0.3)
    for cut in game.cutscenes.played:
        ax1.axvspan(cut.start / 60, cut.end / 60, color="#e0a030", alpha=0.12)

    minutes = [t / 60 for t in trace.t]
    span = max(trace.t[-1] if trace.t else 60, 60)
    bins = [i * span / 24 / 60 for i in range(25)]
    ax2.hist([[e["seconds"] / 60 for e in actions], [e["seconds"] / 60 for e in toggles]],
             bins=bins, stacked=True, color=["#6aa9c9", "#888888"],
             label=["builds / research / crafts", "deposit on-off"],
             weights=[[24 * 60 / span] * len(actions), [24 * 60 / span] * len(toggles)])
    ax2.set_ylabel("actions / min")
    ax2.set_title("Player-action density")
    ax2.legend(fontsize=7, loc="upper right")
    ax2.grid(True, axis="y", alpha=0.3)

    # a minute of smoothing: the raw per-sample counts are pure churn noise, and
    # what matters is the balance between working and walking, not the flicker
    smooth = lambda xs: [sum(xs[max(0, i - 6):i + 6]) / len(xs[max(0, i - 6):i + 6])
                         for i in range(len(xs))]
    ax3.stackplot(minutes, smooth(trace.working), smooth(trace.walking),
                  smooth(trace.idle), labels=["working", "walking", "idle"],
                  colors=["#40c060", "#e0a030", "#cccccc"])
    ax3.plot(minutes, trace.buildings, color="#23deff", lw=1.5, label="buildings")
    ax3.set_xlabel("minutes")
    ax3.set_ylabel("Starknights")
    ax3.legend(fontsize=7, loc="upper left", ncol=4)
    ax3.grid(True, axis="y", alpha=0.3)

    fig.tight_layout()
    fig.savefig(out, dpi=120)
    print(f"  wrote {out}")


# ===========================================================================
def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--goal", default="PC_PC", help="ItemType to produce, e.g. JELLY_STANDEES")
    ap.add_argument("--amount", type=int, default=1)
    ap.add_argument("--research", metavar="NAME",
                    help="instead of an item, race to a research, e.g. 'MekaSuit Integration'")
    ap.add_argument("--minutes", type=float, default=180.0, help="give up after this")
    ap.add_argument("--dt", type=float, default=1 / 30, help="simulation timestep")
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--no-plots", action="store_true")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()

    try:
        game, know, player, trace = play(args.goal, args.amount, args.minutes, args.dt,
                                         args.seed, args.verbose, args.research)
    except LookupError as e:
        print(e, file=sys.stderr)
        return 1
    report(game, know, player, trace, args.dt)
    if not args.no_plots:
        plots(game, player, trace, Path(__file__).with_name("balance_model.png"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
