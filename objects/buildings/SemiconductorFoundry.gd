class_name SemiconductorFoundry
extends FactoryBuilding


func get_display_name() -> String:
	return "Semiconductor Foundry"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_output_upgrade(
		1, "Larger Wafer Boules",
		"Grow bigger crystal boules, doubling semiconductor output.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 20})]
	return items
