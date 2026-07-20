class_name FluidHardwareFactory
extends FactoryBuilding


func get_display_name() -> String:
	return "Fluid Hardware Factory"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_output_upgrade(
		1, "Parallel Machining Cells",
		"Run twice the machining cells, doubling fluid hardware output.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 20})]
	return items
