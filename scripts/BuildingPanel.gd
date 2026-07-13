class_name BuildingPanel
extends PanelContainer


@onready var _title: Label = $VBox/Title
@onready var _popup_button: Button = $VBox/HBox/PopupButton

var _building: Building
var _popup: BuildingPopup


func _ready() -> void:
	hide()
	_popup_button.pressed.connect(_open_popup)
	visibility_changed.connect(_on_visibility_changed)


func show_for(building: Building) -> void:
	_building = building

	_title.text = building.get_display_name()
	_popup_button.visible = building.get_popup() != null

	show()
	_open_popup()


func _close_popup() -> void:
	if is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null


func _open_popup() -> void:
	if is_instance_valid(_popup):
		_popup.queue_free()

	var scene := _building.get_popup()

	if scene == null:
		return

	_popup = scene.instantiate()
	get_parent().add_child(_popup)

	_popup.bind(_building)
	_popup.register_close_handler(_close_popup)


func _on_visibility_changed() -> void:
	if not visible:
		_close_popup()
