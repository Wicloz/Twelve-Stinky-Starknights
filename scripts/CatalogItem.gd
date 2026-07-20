class_name CatalogItem


var scene: PackedScene
var cost: Dictionary[Stockpile.ItemType, int] = {}
var allowed_deposits: Array[Stockpile.ItemType] = []
var always_unlocked: bool = false
var work: float = 10.0

var _scene_probed := false
var _items_produced: Array[Stockpile.ItemType] = []
var _items_consumed: Array[Stockpile.ItemType] = []
var _display_name: String
var _texture: Texture2D
var scale_for_tile: float


func _try_scene_probe() -> void:
    if _scene_probed or scene == null:
        return

    var building = scene.instantiate() as Building

    if building is FactoryBuilding:
        var recipe = Crafting.get_recipe(building.recipe)
        _items_produced.assign(recipe.outputs.keys())
        _items_consumed.assign(recipe.inputs.keys())

    _texture = building.get_node("Sprite2D").texture

    _display_name = building.get_display_name()
    scale_for_tile = building.multiply_by_this()

    _scene_probed = true
    building.queue_free()


func can_place_on(tile: HexTile) -> bool:
    if tile == null:
        return false

    if tile.building != null:
        return false

    if not tile.walkable:
        return false

    if tile.deposit not in allowed_deposits:
        return false

    return true


func try_place_on(tile: HexTile):
    if not can_place_on(tile):
        return "Cannot place this building here."

    var missing: Dictionary[Stockpile.ItemType, int] = {}

    for resource in cost:
        var missing_amount := cost[resource] - Stockpile.get_amount(resource)
        if missing_amount > 0:
            missing[resource] = missing_amount

    if missing.size() > 0:
        var error := "Not enough resources to place this building:"
        for resource in missing:
            error += "\n" + "  - missing %d %s" % [missing[resource], Stockpile.get_display_name(resource)]
        return error

    var building = scene.instantiate() as Building

    tile.set_harvesting(false)

    tile.building = building
    building.tile = tile

    tile.add_child(building)
    building.start_construction(cost, work)

    return false


func get_texture() -> Texture2D:
    _try_scene_probe()
    return _texture


func get_display_name() -> String:
    _try_scene_probe()
    return _display_name


func get_items_produced() -> Array[Stockpile.ItemType]:
    _try_scene_probe()
    return _items_produced


func get_items_consumed() -> Array[Stockpile.ItemType]:
    _try_scene_probe()
    return _items_consumed
