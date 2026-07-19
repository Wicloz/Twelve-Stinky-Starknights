extends Node2D


enum Mode {SELECT, PLACE}
var _mode: Mode = Mode.SELECT

@export var deposit_panel: DepositPanel
@export var building_panel: BuildingPanel
@export var construction_panel: ConstructionPanel

const HOLO_BLUE := preload("res://assets/shaders/holo_blue.tres")
const HOLO_RED := preload("res://assets/shaders/holo_red.tres")
var _place_item: CatalogItem

@onready var _cursor_ghost_place: Node2D = $CursorGhostPlace
@onready var _cursor_place_sprite: Sprite2D = $CursorGhostPlace/Sprite2D
@onready var _cursor_place_label: Label = $CursorGhostPlace/Label

@onready var _cursor_ghost_select: Node2D = $CursorGhostSelect
@onready var _cursor_select_label: Label = $CursorGhostSelect/Label


func _ready() -> void:
	construction_panel.building_selected.connect(_begin_placement)
	building_panel.self_destruct.connect(_on_building_panel_destruct)
	deposit_panel.self_destruct.connect(_on_deposit_panel_destruct)


func _begin_placement(item: CatalogItem) -> void:
	_place_item = item
	_mode = Mode.PLACE

	_cursor_place_sprite.texture = item.get_texture()
	_cursor_place_label.text = ""

	_cursor_ghost_select.hide()
	_cursor_ghost_place.show()


func _end_placement() -> void:
	_place_item = null
	_mode = Mode.SELECT

	_cursor_ghost_place.hide()
	_cursor_ghost_select.show()


func _try_place() -> void:
	var error = _place_item.try_place_on(_hovered_tile())

	if error is not String:
		_end_placement()

	else:
		_cursor_place_label.text = error


func _process(_delta: float) -> void:
	var tile := _hovered_tile()

	match _mode:
		Mode.SELECT:
			_cursor_ghost_select.global_position = get_global_mouse_position()
			_set_hover_text(tile)

		Mode.PLACE:
			if _place_item.can_place_on(tile):
				_cursor_ghost_place.global_position = tile.global_position
				_cursor_place_sprite.material = HOLO_BLUE
			else:
				_cursor_ghost_place.global_position = get_global_mouse_position()
				_cursor_place_sprite.material = HOLO_RED
			if tile != null:
				_cursor_place_sprite.scale = Vector2.ONE * tile.terrain_texture_width * _place_item.scale_for_tile


func _set_hover_text(tile: HexTile) -> void:
	if tile == null:
		_cursor_select_label.text = ""
		return

	if tile.building != null:
		_cursor_select_label.text = tile.building.get_display_name()
	elif tile.deposit != Stockpile.ItemType.NONE:
		_cursor_select_label.text = Stockpile.get_display_name(tile.deposit)
	else:
		_cursor_select_label.text = ""


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


func _on_deposit_panel_destruct() -> void:
	deposit_panel.hide()
	construction_panel.show()


func _hovered_tile() -> HexTile:
	return ZaWarudo.tiles.get(ZaWarudo.world_to_axial(get_global_mouse_position()))
