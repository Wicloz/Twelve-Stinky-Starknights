extends BuildingPopup


var _workshop: Workshop
var _recipes: Array[Recipe] = []

@onready var _recipe_list := $PanelContainer/MarginContainer/VBoxContainer/OrderSelection/Recipes

var _selected_recipe: Recipe
var _selected_repeat: Workshop.Repeat
var _selected_count: int

@onready var _order_repeat := $PanelContainer/MarginContainer/VBoxContainer/OrderConfig/RepeatMode
@onready var _order_count := $PanelContainer/MarginContainer/VBoxContainer/OrderConfig/Count

@onready var _recipe_name := $PanelContainer/MarginContainer/VBoxContainer/OrderSelection/Details/RecipeName
@onready var _recipe_io := $PanelContainer/MarginContainer/VBoxContainer/OrderSelection/Details/RecipeIO
@onready var _recipe_work := $PanelContainer/MarginContainer/VBoxContainer/OrderSelection/Details/RecipeWork

@onready var _order_confirm := $PanelContainer/MarginContainer/VBoxContainer/OrderConfig/Confirm
@onready var _clear_button := $PanelContainer/MarginContainer/VBoxContainer/ClearButton

@onready var _panel := $PanelContainer
@onready var _header := $PanelContainer/MarginContainer/VBoxContainer/Header
@export var close_button: Button

var _dragging := false
var _drag_offset := Vector2.ZERO


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_drag_offset = _panel.get_global_mouse_position() - _panel.global_position
	elif event is InputEventMouseMotion and _dragging:
		_panel.global_position = _panel.get_global_mouse_position() - _drag_offset


func _ready() -> void:
	_recipe_list.item_selected.connect(_on_recipe_selected)
	_order_repeat.item_selected.connect(_on_repeat_selected)
	_order_count.value_changed.connect(_on_count_changed)
	_order_confirm.pressed.connect(_on_confirm_pressed)
	_clear_button.pressed.connect(_on_clear_pressed)
	_header.gui_input.connect(_on_header_gui_input)

	await get_tree().process_frame
	_panel.global_position = (get_viewport_rect().size - _panel.size) / 2


func bind(building: Building) -> void:
	_workshop = building as Workshop

	_selected_recipe = _workshop.order
	_refresh_details()
	_populate_recipes()

	_selected_repeat = _workshop.order_repeat
	_order_repeat.select(_selected_repeat)
	_order_count.visible = _selected_repeat != Workshop.Repeat.FOREVER

	_selected_count = _workshop.order_target
	_order_count.set_value_no_signal(_selected_count)

	_workshop.capabilities_changed.connect(_populate_recipes)


func register_close_handler(close_handler: Callable) -> void:
	close_button.pressed.connect(close_handler)


func _on_recipe_selected(index: int) -> void:
	_selected_recipe = _recipes[index]
	_refresh_details()


func _on_repeat_selected(mode: int) -> void:
	_selected_repeat = mode as Workshop.Repeat
	_order_count.visible = mode != Workshop.Repeat.FOREVER


func _on_count_changed(value: int) -> void:
	_selected_count = value


func _on_clear_pressed() -> void:
	_workshop.clear_order()


func _on_confirm_pressed() -> void:
	_workshop.apply_order(_selected_recipe, _selected_repeat, _selected_count)


func _refresh_details() -> void:
	if _selected_recipe == null:
		_recipe_name.text = "No Order"
		_recipe_io.text = ""
		_recipe_work.text = ""
		return

	_recipe_name.text = _selected_recipe.display_name
	_recipe_io.text = "%s  →  %s" % [_fmt_io(_selected_recipe.inputs), _fmt_io(_selected_recipe.outputs)]
	_recipe_work.text = "%ss" % _selected_recipe.work


func _fmt_io(items: Dictionary) -> String:
	var parts: Array[String] = []
	for item in items:
		parts.append("%d %s" % [items[item], Stockpile.get_display_name(item)])
	return " + ".join(parts)


func _populate_recipes() -> void:
	_recipes.clear()
	_recipe_list.clear()

	for recipe in Crafting.recipes_with_capabilities_satisfied(_workshop.capabilities):
		_recipes.append(recipe)
		_recipe_list.add_item(recipe.display_name)

	var idx = _recipes.find(_selected_recipe)
	if idx != -1:
		_recipe_list.select(idx)

	else:
		_selected_recipe = null
		_recipe_list.deselect_all()
		_refresh_details()
