extends Node2D


enum Mode {SELECT, PLACE}
var _mode: Mode = Mode.SELECT

@export var deposit_panel: DepositPanel
@export var building_panel: BuildingPanel
@export var construction_panel: ConstructionPanel

const HOLO_BLUE := preload("res://assets/shaders/holo_blue.tres")
const HOLO_RED := preload("res://assets/shaders/holo_red.tres")
@onready var _cursor_ghost := $CursorGhost
@onready var _cursor_label := $CursorGhost/Label
var _cursor_item: CatalogItem


func _ready() -> void:
	construction_panel.building_selected.connect(_begin_placement)
	building_panel.self_destruct.connect(_on_building_panel_destruct)


func _begin_placement(item: CatalogItem) -> void:
	_cursor_item = item
	_mode = Mode.PLACE
	_cursor_ghost.texture = item.get_texture()
	_cursor_label.text = ""


func _end_placement() -> void:
	_cursor_item = null
	_mode = Mode.SELECT
	_cursor_ghost.global_position = Vector2(-2000, -2000)
	_cursor_label.text = ""


func _try_place() -> void:
	var error := _cursor_item.try_place_on(_hovered_tile())

	if error == "":
		_end_placement()

	else:
		_cursor_label.text = error


func _process(_delta: float) -> void:
	if _mode != Mode.PLACE:
		return

	var tile := _hovered_tile()

	if _cursor_item.can_place_on(tile):
		_cursor_ghost.global_position = tile.global_position
		_cursor_ghost.material = HOLO_BLUE
	else:
		_cursor_ghost.global_position = get_global_mouse_position()
		_cursor_ghost.material = HOLO_RED


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	match _mode:
		Mode.PLACE:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_try_place()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_end_placement()
		Mode.SELECT:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_select()


func _select() -> void:
	var tile := _hovered_tile()

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


func _on_building_panel_destruct() -> void:
	building_panel.hide()
	construction_panel.show()


func _hovered_tile() -> HexTile:
	return ZaWarudo.tiles.get(ZaWarudo.world_to_axial(get_global_mouse_position()))
