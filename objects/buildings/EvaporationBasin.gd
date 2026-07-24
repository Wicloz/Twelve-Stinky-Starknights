class_name EvaporationBasin
extends FactoryBuilding


func get_display_name() -> String:
	return "Evaporation Basin"


func _upgrade_research() -> Array[ResearchItem]:
	# Output chain (slot 1): evaporate more brine at once.
	var basins := _output_upgrade(
		1, "Wider Basins",
		"Widen the basins to evaporate more brine at once.",
		2, {Stockpile.ItemType.CLAY: 1000})
	var cascade := _output_upgrade(
		1, "Cascade Evaporation",
		"Stage the basins into a multi-effect cascade to concentrate far larger batches.",
		2, {Stockpile.ItemType.CLAY: 100000}, basins)

	# Speed chain (slot 2): boil the brine down faster.
	var solar := _speed_upgrade(
		2, "Solar Concentrators",
		"Focus sunlight on the brine with mirror arrays to evaporate faster.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 15})
	var mvr := _speed_upgrade(
		2, "Vapor Recompression",
		"Recompress the vapour to pump heat back into the brine, evaporating faster still.",
		1.5, {Stockpile.ItemType.ELECTRONIC_ACTUATORS: 8}, solar)

	# Efficiency chain (slot 3): recover more salt from every drop of water.
	var recirc := _efficiency_upgrade(
		3, "Brine Recirculation",
		"Recirculate the brine so more of the dissolved salts crystallise out.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 15})
	var multi_effect := _efficiency_upgrade(
		3, "Multi-Effect Recovery",
		"Reuse each stage's heat to drive the next, wringing evaporites from far less water.",
		1.5, {Stockpile.ItemType.POWER_CELLS: 8}, recirc)

	var items: Array[ResearchItem] = [basins, cascade, solar, mvr, recirc, multi_effect]
	return items
