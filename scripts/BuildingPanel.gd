class_name BuildingPanel
extends PanelContainer


@onready var _title: Label = $VBox/Title


func _ready() -> void:
	hide()


func show_for(building: Building) -> void:
	_title.text = building.get_display_name()
	show()
