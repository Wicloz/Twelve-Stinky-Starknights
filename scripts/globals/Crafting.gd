extends Node


enum Capabilities {
	FURNACE,
	WORKBENCH,
}

enum RecipeType {
	MAKE_IRON,
	MAKE_BRICKS,
	MAKE_PLANKS,
	MAKE_BRASS,
	MAKE_MECHANICAL_COMPONENTS,
	MAKE_GLASS,
}

var _recipe_map: Dictionary[RecipeType, Recipe] = {}


func get_recipe(recipe_type: RecipeType) -> Recipe:
	return _recipe_map[recipe_type]


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
	_recipe_map[RecipeType.MAKE_IRON] = recipe

	recipe.display_name = "Smelt Iron"
	recipe.inputs[Stockpile.ItemType.IRON_ORE] = 1
	recipe.outputs[Stockpile.ItemType.IRON_INGOT] = 1
	recipe.work = 4.0
	recipe.needs_capabilities.append(Capabilities.FURNACE)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_BRICKS] = recipe

	recipe.display_name = "Bake Bricks"
	recipe.inputs[Stockpile.ItemType.CLAY] = 1
	recipe.outputs[Stockpile.ItemType.BRICK] = 1
	recipe.work = 4.0
	recipe.needs_capabilities.append(Capabilities.FURNACE)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_PLANKS] = recipe

	recipe.display_name = "Saw Planks"
	recipe.inputs[Stockpile.ItemType.LUMBER] = 1
	recipe.outputs[Stockpile.ItemType.PLANK] = 8
	recipe.work = 8.0
	recipe.needs_capabilities.append(Capabilities.WORKBENCH)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_BRASS] = recipe

	recipe.display_name = "Smelt Brass"
	recipe.inputs[Stockpile.ItemType.RAW_BRASS] = 1
	recipe.outputs[Stockpile.ItemType.BRASS_INGOT] = 1
	recipe.work = 4.0
	recipe.needs_capabilities.append(Capabilities.FURNACE)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_MECHANICAL_COMPONENTS] = recipe

	recipe.display_name = "Craft Mechanical Components"
	recipe.inputs[Stockpile.ItemType.BRASS_INGOT] = 1
	recipe.inputs[Stockpile.ItemType.PLANK] = 1
	recipe.outputs[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 1
	recipe.work = 8.0
	recipe.needs_capabilities.append(Capabilities.WORKBENCH)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_GLASS] = recipe

	recipe.display_name = "Smelt Glass"
	recipe.inputs[Stockpile.ItemType.SAND] = 1
	recipe.outputs[Stockpile.ItemType.GLASS] = 1
	recipe.work = 4.0
	recipe.needs_capabilities.append(Capabilities.FURNACE)
