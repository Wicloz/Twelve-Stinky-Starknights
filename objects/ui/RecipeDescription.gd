class_name RecipeDescription
extends VBoxContainer


@onready var _recipe_name: Label = $RecipeName
@onready var _recipe_inputs: Label = $RecipeIO/Inputs
@onready var _recipe_outputs: Label = $RecipeIO/Outputs
@onready var _recipe_work: Label = $RecipeWork


func show_recipe(recipe: Recipe) -> void:
	if recipe == null:
		_recipe_name.text = ""
		_recipe_inputs.text = ""
		_recipe_outputs.text = ""
		_recipe_work.text = ""
		return

	_recipe_name.text = recipe.display_name
	_recipe_inputs.text = _fmt_io(recipe.inputs)
	_recipe_outputs.text = _fmt_io(recipe.outputs)
	_recipe_work.text = "%ss" % recipe.work


func _fmt_io(items: Dictionary) -> String:
	var lines: Array[String] = []
	for item in items:
		lines.append("%d %s" % [items[item], Stockpile.get_display_name(item)])
	return "\n".join(lines)


func pin_min_size(recipes: Array[Recipe]) -> void:
	var name_font: Font = _recipe_name.get_theme_font("font")
	var name_size: int = _recipe_name.get_theme_font_size("font_size")
	var io_font: Font = _recipe_inputs.get_theme_font("font")
	var io_size: int = _recipe_inputs.get_theme_font_size("font_size")
	var work_font: Font = _recipe_work.get_theme_font("font")
	var work_size: int = _recipe_work.get_theme_font_size("font_size")

	# Pin each variable label to the largest content any recipe could show, so
	# selecting a different recipe never resizes the popup. Sizing the two IO
	# columns independently lets the HBox lay them out without extra math.
	var name_width: float = 0
	var work_width: float = 0
	var inputs_width: float = 0
	var outputs_width: float = 0
	var max_io_lines: int = 0
	for recipe in recipes:
		name_width = max(name_width, name_font.get_string_size(recipe.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x)
		work_width = max(work_width, work_font.get_string_size("%ss" % recipe.work, HORIZONTAL_ALIGNMENT_LEFT, -1, work_size).x)
		for item in recipe.inputs:
			var line := "%d %s" % [recipe.inputs[item], Stockpile.get_display_name(item)]
			inputs_width = max(inputs_width, io_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, io_size).x)
		for item in recipe.outputs:
			var line := "%d %s" % [recipe.outputs[item], Stockpile.get_display_name(item)]
			outputs_width = max(outputs_width, io_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, io_size).x)
		max_io_lines = max(max_io_lines, recipe.inputs.size(), recipe.outputs.size())

	var io_height: float = io_font.get_height(io_size) * max_io_lines
	_recipe_name.custom_minimum_size.x = name_width
	_recipe_work.custom_minimum_size.x = work_width
	_recipe_inputs.custom_minimum_size = Vector2(inputs_width, io_height)
	_recipe_outputs.custom_minimum_size = Vector2(outputs_width, io_height)
