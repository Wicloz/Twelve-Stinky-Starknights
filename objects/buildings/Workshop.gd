class_name Workshop
extends Building
signal capabilities_changed


const POPUP := preload("res://objects/buildings/WorkshopPopup.tscn")

var capabilities: Array[Crafting.Capabilities] = [Crafting.Capabilities.FURNACE]

enum Repeat {FOREVER, COUNT, UNTIL}

var order: Recipe = null
var order_repeat: Repeat
var order_target: int


func get_display_name() -> String:
	return "Workshop"


func get_popup() -> PackedScene:
	return POPUP


func has_capabilities(required: Array[Crafting.Capabilities]) -> bool:
	for capability in required:
		if not capabilities.has(capability):
			return false
	return true
