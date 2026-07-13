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
	recipe.inputs[Stockpile.ItemType.ORE] = 1
	recipe.outputs[Stockpile.ItemType.INGOTS] = 1
	recipe.work = 5.0
	recipe.needs_capabilities.append(Capabilities.FURNACE)

	recipe = Recipe.new()
	recipes.append(recipe)

	recipe.display_name = "Bake Bricks"
	recipe.inputs[Stockpile.ItemType.CLAY] = 1
	recipe.outputs[Stockpile.ItemType.BRICKS] = 1
	recipe.work = 5.0
	recipe.needs_capabilities.append(Capabilities.FURNACE)

	recipe = Recipe.new()
	recipes.append(recipe)

	recipe.display_name = "Saw Planks"
	recipe.inputs[Stockpile.ItemType.LUMBER] = 1
	recipe.outputs[Stockpile.ItemType.PLANKS] = 1
	recipe.work = 5.0
	recipe.needs_capabilities.append(Capabilities.WORKBENCH)
