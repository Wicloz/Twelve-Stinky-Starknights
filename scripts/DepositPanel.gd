class_name DepositPanel
extends PanelContainer


var _tile: HexTile

@onready var _title: Label = $VBox/Title
@onready var _toggle: CheckButton = $VBox/Toggle


func _ready() -> void:
	hide()
	_toggle.toggled.connect(_on_harvest_toggled)


func show_for(tile: HexTile) -> void:
	_tile = tile
	_title.text = Stockpile.get_display_name(tile.deposit)

	_toggle.visible = tile.workable
	_toggle.set_pressed_no_signal(tile.harvesting)

	show()


func _on_harvest_toggled(pressed: bool) -> void:
	_tile.set_harvesting(pressed)
