extends Building


var capabilities: Array[Crafting.Capabilities] = [Crafting.Capabilities.FURNACE]
var order: Recipe = null


func get_display_name() -> String:
	return "Workshop"
