class_name DepositPanel
extends PanelContainer
signal self_destruct


var _tile: HexTile

@onready var _title: Label = $VBox/Header/Title
@onready var _toggle: CheckButton = $VBox/HBox/Toggle
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

	show()


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
