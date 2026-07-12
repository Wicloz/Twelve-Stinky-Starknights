class_name Production


enum Capabilities {
	FURNACE,
}


var recipes: Array[Recipe]


func _ready() -> void:
	_make("Smelt Metal", {Stockpile.ItemType.ORE: 1}, {Stockpile.ItemType.INGOT: 1}, 5.0, [Capabilities.FURNACE])


func _make(display_name: String,
		inputs: Dictionary[Stockpile.ItemType, int],
		outputs: Dictionary[Stockpile.ItemType, int],
		work: float,
		needs_capabilities: Array[Capabilities]) -> Recipe:
	var recipe := Recipe.new()
	recipe.display_name = display_name
	recipe.inputs = inputs
	recipe.outputs = outputs
	recipe.work = work
	recipe.needs_capabilities = needs_capabilities
	return recipe
