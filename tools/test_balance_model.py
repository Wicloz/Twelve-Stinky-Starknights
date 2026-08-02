#!/usr/bin/env python
"""Self-check for the balance model. Run: python test_balance_model.py

Three things can quietly go wrong, so each gets one check:
  * the GDScript translation silently loading the WRONG numbers,
  * travel_time (the one method sim.py reimplements) disagreeing with the game's,
  * the whole thing not actually playing the game.
"""

import math

import balance_model as bm
import sim


def test_data_comes_from_the_source():
    """Spot-check values against the .gd files -- if the translator drops a line,
    these are what notice."""
    game = sim.Game()
    I = game.items

    bricks = game.crafting.get_recipe(game.crafting.RecipeType.MAKE_BRICKS)
    assert dict(bricks.inputs) == {I.CLAY: 1}, dict(bricks.inputs)
    assert dict(bricks.outputs) == {I.BRICKS: 1}, dict(bricks.outputs)
    assert bricks.work == game.crafting.WORK_SMELTING == 4.0, bricks.work

    warehouse = next(e for e in game.catalog._catalog if "Warehouse" in e.scene.path)
    assert dict(warehouse.cost) == {I.CLAY: 100, I.RAW_TITANIUM: 100}, dict(warehouse.cost)

    assert game.stockpile.get_challenge_limit(I.WHITE_PAINT) == 216
    assert game.stockpile.is_unavailable_story_item(I.PC_PC)      # locked until the story

    # Challenge._limit is `false` when there is no limit, and `false is int` is
    # false in GDScript -- but Python's bool subclasses int, so an isinstance
    # translation silently completes every unlimited challenge on first sight
    limited = game.stockpile._challenges[I.PC_RAM]
    unlimited = game.stockpile._challenges[I.JELLY_STANDEES]
    assert limited.is_limit_reached(4) and not limited.is_limit_reached(3)
    assert not unlimited.is_limit_reached(10 ** 6)

    # the Pitmine's first yield upgrade doubles the harvest, and its effect runs
    game.register_all_research()
    pitmine = game.building_classes["Pitmine"]
    wider = next(r for r in game.research._items if r.display_name == "Wider Pit")
    assert dict(wider.cost) == {I.PLANKS: 40}, dict(wider.cost)
    wider.on_complete()
    assert pitmine.yield_scale[pitmine] == 2, pitmine.yield_scale

    # 12 Starknights, one Workshop, and a map with deposits on it
    assert len(game.knights) == 12
    assert sum(1 for t in game.tiles.values() if t.workable) > 10


def test_travel_time_matches_walking_the_path():
    """sim.py answers travel_time() from a path table instead of walking the list.
    It must agree with the game's own arithmetic, or every job costs the wrong
    amount of Starknight."""
    game = sim.Game()
    knight = game.knights[0]
    targets = [t for t in game.tiles.values() if t.walkable][:40]
    for target in targets:
        path = knight._path_to(target)
        expected = 0.0
        if path:
            here = knight.position
            for tile in path:
                expected += here.distance_to(tile.position)
                here = tile.position
            expected /= knight._get_speed()
        elif target is not knight._footing():
            expected = math.inf
        got = knight.travel_time(target)
        assert abs(got - expected) < 1e-9 or (got == expected == math.inf), \
            (target.q, target.r, got, expected)


def test_harvest_is_sticky():
    """HexTile re-posts its job from inside the completion handler, so the knight
    standing there keeps it. If that ever breaks, a tile yields far less than one
    item a second and every pacing number moves."""
    game = sim.Game()
    tile = next(t for t in game.tiles.values()
                if t.workable and t.deposit == game.items.RAW_TITANIUM)
    tile.set_harvesting(True)
    while game.now < 120:
        game.tick()
    walked = game.world.walk_length(game.workshop.tile, tile) / 100.0
    mined = game.stockpile.get_amount(game.items.RAW_TITANIUM)
    assert mined > (120 - walked - 5), (mined, walked)


def test_it_plays_the_game():
    """A whole (short) playthrough: the player builds, the story runs, the goal
    arrives."""
    game, know, player, trace = bm.play("BRICKS", 200, minutes=10, dt=1 / 20, seed=1)
    assert player.done_at is not None, "never made 200 bricks"
    assert player.done_at < 600
    kinds = {e["kind"] for e in game.log.entries}
    assert {"build", "craft", "harvest"} <= kinds, kinds
    assert any(c.scene.var_name == "opening_sakana" for c in game.cutscenes.played)
    assert trace.working and max(trace.working) > 0


if __name__ == "__main__":
    test_data_comes_from_the_source()
    test_travel_time_matches_walking_the_path()
    test_harvest_is_sticky()
    test_it_plays_the_game()
    print("ok")
