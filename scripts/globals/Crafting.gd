extends Node


enum Capabilities {
	FURNACE,
}

var recipes: Array[Recipe]


func _ready() -> void:
	var recipe = Recipe.new()
	recipes.append(recipe)

	recipe.display_name = "Smelt Metal"
	recipe.inputs = {Stockpile.ItemType.ORE: 1}
	recipe.outputs = {Stockpile.ItemType.INGOT: 1}
	recipe.work = 5.0
	recipe.needs_capabilities = [Capabilities.FURNACE]
