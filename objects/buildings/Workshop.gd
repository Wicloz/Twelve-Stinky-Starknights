extends Building


var capabilities: Array[Production.Capabilities] = [Production.Capabilities.FURNACE]
var order: Recipe = null


func get_display_name() -> String:
	return "Workshop"
