extends Node2D


@export var deposit_panel: DepositPanel
@export var building_panel: BuildingPanel
@export var construction_panel: ConstructionPanel


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var coord := ZaWarudo.world_to_axial(get_global_mouse_position())
	var tile: HexTile = ZaWarudo.tiles.get(coord)

	if tile == null:
		deposit_panel.hide()
		building_panel.hide()
		construction_panel.show()

	elif tile.building != null:
		deposit_panel.hide()
		building_panel.show_for(tile.building)
		construction_panel.hide()

	elif tile.deposit != Stockpile.ItemType.NONE:
		deposit_panel.show_for(tile)
		building_panel.hide()
		construction_panel.hide()

	else:
		deposit_panel.hide()
		building_panel.hide()
		construction_panel.show()
