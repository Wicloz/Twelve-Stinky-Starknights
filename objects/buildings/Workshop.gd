extends Building


const POPUP := preload("res://objects/buildings/WorkshopPopup.tscn")

var capabilities: Array[Crafting.Capabilities] = [Crafting.Capabilities.FURNACE]
var order: Recipe = null


func get_display_name() -> String:
	return "Workshop"


func get_popup() -> PackedScene:
	return POPUP
