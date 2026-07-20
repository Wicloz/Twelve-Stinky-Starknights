class_name BuildingPanel
extends PanelContainer
signal self_destruct


@export var cancel_icon: Texture2D
@export var demolish_icon: Texture2D

@onready var _title: Label = $VBox/Header/Title
@onready var _close: TextureButton = $VBox/Header/Close

@onready var _destruct_button: TextureButton = $VBox/HBox/DestructButton
@onready var _popup_button: Button = $VBox/HBox/PopupButton

@onready var _research: GridContainer = $VBox/HBox/Research
var _research_buttons: Array[Button] = []

@onready var _recipe_description: RecipeDescription = $VBox/HBox/RecipeDescription

var _building: Building
var _popup: BuildingPopup
var _research_items: Array[ResearchItem] = []


func _ready() -> void:
	hide()
	_popup_button.pressed.connect(_open_popup)
	_destruct_button.pressed.connect(_on_destruct_pressed)
	_close.pressed.connect(_on_close_pressed)

	for button in _research.get_children():
		_research_buttons.append(button)

	for idx in _research_buttons.size():
		_research_buttons[idx].pressed.connect(_on_research_button_pressed.bind(idx))
		_research_items.append(null)

	Research.changed.connect(_refresh_research)
	Research.changed.connect(_refresh_recipe)
	Stockpile.changed.connect(_refresh_research)


func show_for(building: Building) -> void:
	_building = building

	_title.text = building.get_display_name()
	_popup_button.visible = building.has_popup()

	building.constructed.connect(_on_building_constructed)
	_set_destruct_icon()
	_destruct_button.visible = building.can_demolish()

	show()

	_refresh_recipe()
	_refresh_research()
	_open_popup()


func hide_panel() -> void:
	_close_popup()
	hide()

	if is_instance_valid(_building) and _building.constructed.is_connected(_on_building_constructed):
		_building.constructed.disconnect(_on_building_constructed)


func _on_building_constructed() -> void:
	_set_destruct_icon()
	_refresh_research()


func _refresh_recipe() -> void:
	if not visible or _building == null:
		return

	var recipe := _building.get_display_recipe()
	_recipe_description.visible = recipe != null
	_recipe_description.show_recipe(recipe)


func _refresh_research() -> void:
	if not visible:
		return

	_research_items.fill(null)
	for item in Research.available_for(_building):
		_research_items[item.slot - 1] = item

	for i in _research_buttons.size():
		_bind_research_button(_research_buttons[i], _research_items[i])


func _bind_research_button(research_button: Button, item: ResearchItem) -> void:
	if item == null:
		research_button.icon = null
		research_button.text = ""
		research_button.tooltip_text = ""
		research_button.disabled = true
		return

	research_button.icon = item.texture
	research_button.text = "" if item.texture else item.acronym()
	research_button.tooltip_text = item.tooltip()
	research_button.disabled = not _building.is_constructed() or not Research.can_research(item)


func _on_research_button_pressed(index: int) -> void:
	var item := _research_items[index]
	if item == null:
		return

	Research.start_research(item, _building)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _destruct_button.visible:
		return

	if event.is_action_pressed("demolish"):
		_on_destruct_pressed()
		get_viewport().set_input_as_handled()


func _on_destruct_pressed() -> void:
	if _building.is_constructed():
		_building.demolish()
	else:
		_building.abort()
	self_destruct.emit()


func _on_close_pressed() -> void:
	self_destruct.emit()


func _set_destruct_icon() -> void:
	if _building.is_constructed():
		_destruct_button.texture_normal = demolish_icon
		_destruct_button.tooltip_text = "Demolish (del)"
	else:
		_destruct_button.texture_normal = cancel_icon
		_destruct_button.tooltip_text = "Cancel Construction (del)"


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
