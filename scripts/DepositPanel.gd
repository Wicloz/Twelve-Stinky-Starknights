class_name DepositPanel
extends PanelContainer
signal self_destruct
signal building_placed(tile: HexTile)


const CELL := Vector2(60, 85)

var _tile: HexTile

@onready var _title: Label = $VBox/Header/Title
@onready var _toggle: CheckButton = $VBox/HBox/Toggle
@onready var _buildings: HBoxContainer = $VBox/HBox/Buildings
@onready var _error: Label = $VBox/HBox/Error
@onready var _close: TextureButton = $VBox/Header/Close


func _ready() -> void:
	hide()
	_toggle.toggled.connect(_on_harvest_toggled)
	_close.pressed.connect(_on_close_pressed)


func show_for(tile: HexTile) -> void:
	_tile = tile
	_title.text = Stockpile.get_display_name(tile.deposit)

	_toggle.visible = tile.workable
	_toggle.set_pressed_no_signal(tile.harvesting)

	_error.hide()
	_refresh_buildings()

	show()


func _refresh_buildings() -> void:
	for button in _buildings.get_children():
		_buildings.remove_child(button)
		button.queue_free()

	for item in Catalog.get_unlocked_buildings():
		if item.can_place_on(_tile):
			_buildings.add_child(_make_button(item))


func _make_button(item: CatalogItem) -> Button:
	var button := Button.new()

	button.custom_minimum_size = CELL
	button.custom_maximum_size = CELL

	button.tooltip_text = "Construct " + item.get_display_name() + "\n"
	for resource in item.cost:
		button.tooltip_text += "\n%s: %d" % [Stockpile.get_display_name(resource), item.cost[resource]]

	button.icon = item.get_texture()
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER

	button.pressed.connect(_on_build_pressed.bind(item))

	return button


func _on_build_pressed(item: CatalogItem) -> void:
	var error = item.try_place_on(_tile)

	if error is String:
		_error.text = error
		_error.show()
		return

	building_placed.emit(_tile)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _toggle.visible:
		return

	if event.is_action_pressed("toggle_harvest"):
		_toggle.button_pressed = not _toggle.button_pressed
		get_viewport().set_input_as_handled()


func _on_harvest_toggled(pressed: bool) -> void:
	_tile.set_harvesting(pressed)


func _on_close_pressed() -> void:
	self_destruct.emit()
