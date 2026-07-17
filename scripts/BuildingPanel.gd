class_name BuildingPanel
extends PanelContainer
signal self_destruct


@export var cancel_icon: Texture2D
@export var demolish_icon: Texture2D

@onready var _title: Label = $VBox/Title
@onready var _destruct_button: TextureButton = $VBox/HBox/DestructButton
@onready var _popup_button: Button = $VBox/HBox/PopupButton

var _building: Building
var _popup: BuildingPopup


func _ready() -> void:
	hide()
	_popup_button.pressed.connect(_open_popup)
	visibility_changed.connect(_on_visibility_changed)
	_destruct_button.pressed.connect(_on_destruct_pressed)


func show_for(building: Building) -> void:
	_building = building

	_title.text = building.get_display_name()
	_popup_button.visible = building.has_popup()

	_building.constructed.connect(_set_destruct_icon)
	_set_destruct_icon()
	_destruct_button.visible = building.can_demolish()

	show()
	_open_popup()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _destruct_button.visible:
		return

	if event.is_action_pressed("demolish"):
		_on_destruct_pressed()
		get_viewport().set_input_as_handled()


func _on_destruct_pressed() -> void:
	_building.demolish()
	self_destruct.emit()


func _set_destruct_icon() -> void:
	if _building.is_constructed():
		_destruct_button.texture_normal = demolish_icon
	else:
		_destruct_button.texture_normal = cancel_icon


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
