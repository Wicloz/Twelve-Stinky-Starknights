class_name CatalogItem


var display_name: String
var scene: PackedScene
var texture: Texture2D
var cost: Dictionary[Stockpile.ItemType, int] = {}

const ICON_REGION := Rect2(0, 0, 120, 170)
var _icon: AtlasTexture


func can_place_on(tile: HexTile) -> bool:
    if tile == null:
        return false

    if tile.building != null:
        return false

    if tile.deposit != Stockpile.ItemType.NONE:
        return false

    return true


func try_place_on(tile: HexTile) -> bool:
    if not can_place_on(tile):
        return false

    for resource in cost:
        if Stockpile.get_amount(resource) < cost[resource]:
            return false

    var building = scene.instantiate() as Building
    building.z_index = tile.z_index + 1

    tile.set_harvesting(false)

    tile.building = building
    building.tile = tile

    tile.add_child(building)
    building.start_construction(cost)

    return true


func get_icon() -> AtlasTexture:
    if _icon == null:
        _icon = AtlasTexture.new()
        _icon.atlas = texture
        _icon.region = ICON_REGION
    return _icon
