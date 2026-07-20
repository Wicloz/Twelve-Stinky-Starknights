class_name ElectronicComponentFactory
extends FactoryBuilding


func get_display_name() -> String:
	return "Electronic Component Factory"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_output_upgrade(
		1, "Panelized Assembly",
		"Assemble components on shared panels, doubling output.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 20})]
	return items
