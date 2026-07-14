extends Node


enum Capabilities {
	FURNACE,
	WORKBENCH,
}

var recipes: Array[Recipe]


func _ready() -> void:
	var recipe: Recipe

	recipe = Recipe.new()
	recipes.append(recipe)

	recipe.display_name = "Smelt Metal"
	recipe.inputs[Stockpile.ItemType.IRON_ORE] = 1
	recipe.outputs[Stockpile.ItemType.IRON_INGOT] = 1
	recipe.work = 4.0
	recipe.needs_capabilities.append(Capabilities.FURNACE)

	recipe = Recipe.new()
	recipes.append(recipe)

	recipe.display_name = "Bake Bricks"
	recipe.inputs[Stockpile.ItemType.CLAY] = 1
	recipe.outputs[Stockpile.ItemType.BRICK] = 1
	recipe.work = 4.0
	recipe.needs_capabilities.append(Capabilities.FURNACE)

	recipe = Recipe.new()
	recipes.append(recipe)

	recipe.display_name = "Saw Planks"
	recipe.inputs[Stockpile.ItemType.LUMBER] = 1
	recipe.outputs[Stockpile.ItemType.PLANK] = 8
	recipe.work = 8.0
	recipe.needs_capabilities.append(Capabilities.WORKBENCH)

	recipe = Recipe.new()
	recipes.append(recipe)

	recipe.display_name = "Craft Mechanical Components"
	recipe.inputs[Stockpile.ItemType.RAW_BRASS] = 1
	recipe.outputs[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 1
	recipe.work = 8.0
	recipe.needs_capabilities.append(Capabilities.WORKBENCH)
