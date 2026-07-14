class_name CatalogItem


var display_name: String
var scene: PackedScene
var texture: Texture2D
var cost: Dictionary[Stockpile.ItemType, int] = {}


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

    tile.building = building
    building.tile = tile

    tile.add_child(building)
    building.start_construction(cost)

    return true
