class_name IntegratedCircuitFab
extends FactoryBuilding


func get_display_name() -> String:
	return "IC Fab"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_output_upgrade(
		1, "Higher Wafer Yield",
		"Tighter process control doubles the ICs harvested per wafer.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 20})]
	return items
