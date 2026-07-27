class_name EvaporationBasin
extends FactoryBuilding


func get_display_name() -> String:
	return "Evaporation Basin"


# Civil works, not machinery: the cheapest way to evaporate more brine is simply to
# dig and line more ground, so the output chain runs on bulk clay and brick even
# though the basin feeds the late semiconductor chain. No capstone.
func _upgrade_research() -> Array[ResearchItem]:
	# Output chain (slot 1): evaporate more brine at once.
	var basins := _output_upgrade(
		1, "Wider Basins",
		"Dig out and puddle far more ground with clay to hold a much larger spread of brine.",
		2, {Stockpile.ItemType.CLAY: 150})
	var cascade := _output_upgrade(
		1, "Cascade Evaporation",
		"Step the pans down a brick cascade so each stage concentrates the last.",
		2, {Stockpile.ItemType.BRICKS: 200, Stockpile.ItemType.FLUID_HARDWARE: 20}, basins)

	# Speed chain (slot 2): boil the brine down faster.
	var solar := _speed_upgrade(
		2, "Solar Concentrators",
		"Steerable mirror troughs focus the sun onto the pans to evaporate faster.",
		1.5, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 25, Stockpile.ItemType.PLASTIC: 30})
	var mvr := _speed_upgrade(
		2, "Vapor Recompression",
		"Recompress the vapour and pump its own heat back into the brine.",
		1.5, {Stockpile.ItemType.ELECTRONIC_ACTUATORS: 8, Stockpile.ItemType.POWER_CELLS: 10}, solar)

	# Efficiency chain (slot 3): recover more salt from every drop of water.
	var recirc := _efficiency_upgrade(
		3, "Brine Recirculation",
		"Pump the weak brine back over the pans until more of its salts crystallise out.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 20})
	var multi_effect := _efficiency_upgrade(
		3, "Multi-Effect Recovery",
		"Banks of cupronickel tubes reuse each stage's heat, wringing evaporites from far less water.",
		1.5, {Stockpile.ItemType.CUPRONICKEL_INGOTS: 40, Stockpile.ItemType.POWER_CELLS: 8}, recirc)

	var items: Array[ResearchItem] = [basins, cascade, solar, mvr, recirc, multi_effect]
	return items
