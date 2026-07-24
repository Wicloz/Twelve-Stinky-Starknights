extends BuildingPopup


const BUILDING_PANEL_HEIGHT := 210

var _workshop: Workshop
var _recipes: Array[Recipe] = []

@onready var _recipe_list := $PanelContainer/VBoxContainer/OrderSelection/Recipes

var _selected_recipe: Recipe
var _selected_repeat: Workshop.Repeat
var _selected_count: int

@onready var _order_repeat := $PanelContainer/VBoxContainer/OrderConfig/RepeatMode
@onready var _order_count := $PanelContainer/VBoxContainer/OrderConfig/Count

@onready var _details: RecipeDescription = $PanelContainer/VBoxContainer/OrderSelection/Details

@onready var _order_confirm := $PanelContainer/VBoxContainer/OrderConfig/Confirm
@onready var _clear_button := $PanelContainer/VBoxContainer/ClearButton

@onready var _panel := $PanelContainer
@onready var _header := $PanelContainer/VBoxContainer/Header
@export var close_button: BaseButton

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

	_populate_recipes()
	Research.changed.connect(_populate_recipes)
	Stockpile.challenge_updated.connect(_populate_recipes)

	_details.pin_min_size(Crafting.all_recipes())
	await get_tree().process_frame

	var usable_screen_space := get_viewport_rect().size
	usable_screen_space.x *= 0.75
	usable_screen_space.y -= BUILDING_PANEL_HEIGHT

	_panel.global_position = (usable_screen_space - _panel.size) / 2


func bind(building: Building) -> void:
	_workshop = building as Workshop

	_selected_recipe = _workshop.order
	_refresh_details()

	_selected_repeat = _workshop.order_repeat
	_order_repeat.select(_selected_repeat)
	_order_count.visible = _selected_repeat != Workshop.Repeat.FOREVER

	_selected_count = _workshop.order_target
	_order_count.set_value_no_signal(_selected_count)


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
	_details.show_recipe(_selected_recipe)


func _populate_recipes() -> void:
	_recipes.clear()
	_recipe_list.clear()

	for recipe in Crafting.recipes_for_workshop():
		_recipes.append(recipe)
		_recipe_list.add_item(recipe.display_name)

	var idx = _recipes.find(_selected_recipe)
	if idx != -1:
		_recipe_list.select(idx)

	else:
		_selected_recipe = null
		_recipe_list.deselect_all()
		_refresh_details()
