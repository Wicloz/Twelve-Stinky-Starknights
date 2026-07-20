class_name PowerCellFactory
extends FactoryBuilding


func get_display_name() -> String:
	return "Power Cell Factory"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_output_upgrade(
		1, "Stacked Cell Lines",
		"Run assembly lines in parallel, doubling power cell output.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 20})]
	return items
