class_name CatalogItem


var scene: PackedScene
var cost: Dictionary[Stockpile.ItemType, int] = {}
var allowed_deposits: Array[Stockpile.ItemType] = []

const ICON_REGION := Rect2(0, 0, 120, 170)

var _scene_probed := false
var _items_produced: Array[Stockpile.ItemType] = []
var _items_consumed: Array[Stockpile.ItemType] = []
var _display_name: String
var _texture: Texture2D
var _icon: AtlasTexture


func _try_scene_probe() -> void:
    if _scene_probed or scene == null:
        return

    var building = scene.instantiate() as Building

    if building is FactoryBuilding:
        var recipe = Crafting.get_recipe(building.recipe)
        _items_produced.assign(recipe.outputs.keys())
        _items_consumed.assign(recipe.inputs.keys())

    _texture = building.get_node("Sprite2D").texture

    _icon = AtlasTexture.new()
    _icon.atlas = _texture
    _icon.region = ICON_REGION

    _display_name = building.get_display_name()
    _scene_probed = true

    building.queue_free()


func can_place_on(tile: HexTile) -> bool:
    if tile == null:
        return false

    if tile.building != null:
        return false

    if tile.deposit not in allowed_deposits:
        return false

    return true


func try_place_on(tile: HexTile):
    if not can_place_on(tile):
        return "Cannot place this building here."

    for resource in cost:
        if Stockpile.get_amount(resource) < cost[resource]:
            return "Not enough resources to place this building."

    var building = scene.instantiate() as Building
    building.z_index = tile.z_index + 1

    tile.set_harvesting(false)

    tile.building = building
    building.tile = tile

    tile.add_child(building)
    building.start_construction(cost)

    return false


func get_icon() -> AtlasTexture:
    _try_scene_probe()
    return _icon


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
