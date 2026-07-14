class_name CatalogItem


var display_name: String
var scene: PackedScene
var texture: Texture2D
var cost: Dictionary[Stockpile.ItemType, int] = {}
var allowed_deposits: Array[Stockpile.ItemType] = []

const ICON_REGION := Rect2(0, 0, 120, 170)
var _icon: AtlasTexture


func can_place_on(tile: HexTile) -> bool:
    if tile == null:
        return false

    if tile.building != null:
        return false

    if tile.deposit not in allowed_deposits:
        return false

    return true


func try_place_on(tile: HexTile) -> String:
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

    return ""


func get_icon() -> AtlasTexture:
    if _icon == null:
        _icon = AtlasTexture.new()
        _icon.atlas = texture
        _icon.region = ICON_REGION
    return _icon
