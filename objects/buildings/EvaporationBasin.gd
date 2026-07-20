class_name EvaporationBasin
extends FactoryBuilding


func get_display_name() -> String:
	return "Evaporation Basin"


func _upgrade_research() -> Array[ResearchItem]:
	var basins := _output_upgrade(
		1, "Wider Basins",
		"Evaporate more brine at once, doubling evaporite output.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 20})

	var cascade := _output_upgrade(
		2, "Cascade Evaporation",
		"Stage the basins to concentrate even larger batches.",
		3, {Stockpile.ItemType.FLUID_HARDWARE: 50}, basins)

	var solar := _speed_upgrade(
		3, "Solar Concentrators",
		"Focus sunlight on the brine to evaporate twice as fast.",
		2.0, {Stockpile.ItemType.FLUID_HARDWARE: 30})

	var items: Array[ResearchItem] = [basins, cascade, solar]
	return items
