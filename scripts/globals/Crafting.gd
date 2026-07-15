extends Node


enum Capabilities {
	FURNACE,
	WORKBENCH,
}

enum RecipeType {
	MAKE_PLANKS,
	MAKE_BRICKS,

	MAKE_BRASS,
	MAKE_MECHANICAL_COMPONENTS,

	MAKE_CUPRONICKEL,
	MAKE_FLUID_HARDWARE,
}

var _recipe_map: Dictionary[RecipeType, Recipe] = {}


func get_recipe(recipe_type: RecipeType) -> Recipe:
	return _recipe_map[recipe_type]


func all_recipes() -> Array[Recipe]:
	return _recipe_map.values()


func recipes_with_capabilities_satisfied(capabilities: Array[Capabilities]) -> Array[Recipe]:
	var result: Array[Recipe] = []

	for recipe in _recipe_map.values():
		var satisfied = true

		for capability in recipe.needs_capabilities:
			if not capabilities.has(capability):
				satisfied = false
				break

		if satisfied:
			result.append(recipe)

	return result


func _ready() -> void:
	var recipe: Recipe

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_BRICKS] = recipe

	recipe.display_name = "Bake Bricks"
	recipe.inputs[Stockpile.ItemType.CLAY] = 1
	recipe.outputs[Stockpile.ItemType.BRICKS] = 1
	recipe.work = 4.0
	recipe.needs_capabilities.append(Capabilities.FURNACE)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_PLANKS] = recipe

	recipe.display_name = "Saw Planks"
	recipe.inputs[Stockpile.ItemType.LUMBER] = 1
	recipe.outputs[Stockpile.ItemType.PLANKS] = 8
	recipe.work = 8.0
	recipe.needs_capabilities.append(Capabilities.WORKBENCH)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_BRASS] = recipe

	recipe.display_name = "Smelt Brass"
	recipe.inputs[Stockpile.ItemType.RAW_BRASS] = 1
	recipe.outputs[Stockpile.ItemType.BRASS_INGOTS] = 1
	recipe.work = 4.0
	recipe.needs_capabilities.append(Capabilities.FURNACE)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_MECHANICAL_COMPONENTS] = recipe

	recipe.display_name = "Craft Mechanical Components"
	recipe.inputs[Stockpile.ItemType.BRASS_INGOTS] = 1
	recipe.inputs[Stockpile.ItemType.PLANKS] = 1
	recipe.outputs[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 1
	recipe.work = 8.0
	recipe.needs_capabilities.append(Capabilities.WORKBENCH)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_CUPRONICKEL] = recipe

	recipe.display_name = "Smelt Cupronickel"
	recipe.inputs[Stockpile.ItemType.RAW_CUPRONICKEL] = 1
	recipe.outputs[Stockpile.ItemType.CUPRONICKEL_INGOTS] = 1
	recipe.work = 4.0
	recipe.needs_capabilities.append(Capabilities.FURNACE)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_FLUID_HARDWARE] = recipe

	recipe.display_name = "Manufacture Fluid Hardware"
	recipe.inputs[Stockpile.ItemType.CUPRONICKEL_INGOTS] = 2
	recipe.outputs[Stockpile.ItemType.FLUID_PIPES] = 1
	recipe.outputs[Stockpile.ItemType.PRESSURE_VESSELS] = 1
	recipe.work = 16.0
