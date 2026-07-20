class_name EvaporationBasin
extends FactoryBuilding


func get_display_name() -> String:
	return "Evaporation Basin"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_output_upgrade(
		1, "Cascade Evaporation",
		"Staged basins concentrate far larger batches, tripling evaporite output.",
		3, {Stockpile.ItemType.FLUID_HARDWARE: 30})]
	return items
