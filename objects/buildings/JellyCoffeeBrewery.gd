class_name JellyCoffeeBrewery
extends FactoryBuilding


func get_display_name() -> String:
	return "Jelly Coffee Brewery"


func _upgrade_research() -> Array[ResearchItem]:
	# Output chain (slot 1): brew a bigger batch each cycle.
	var kettle := _output_upgrade(
		1, "Bigger Brew Kettle",
		"Brew more cherries per batch in a larger kettle.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 15})
	var continuous := _output_upgrade(
		1, "Continuous Brewing Line",
		"A continuous-flow brewing line pours far larger batches.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 12}, kettle)

	# Speed chain (slot 2): pull the extraction faster.
	var pressure := _speed_upgrade(
		2, "Pressure Brewing",
		"Pressurised extraction brews each batch faster.",
		1.5, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 15})
	var flash := _speed_upgrade(
		2, "Flash Extraction",
		"Flash-heat the slurry to extract in seconds, brewing faster still.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 12}, pressure)

	# Efficiency chain (slot 3): get more coffee from every cherry.
	var recirc := _efficiency_upgrade(
		3, "Grounds Recirculation",
		"Re-steep the grounds to pull more from each cherry, using fewer per batch.",
		1.5, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 15})
	var concentrate := _efficiency_upgrade(
		3, "Cold-Brew Concentration",
		"A slow cold-brew stage concentrates the yield, sipping far fewer cherries.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 12}, recirc)

	var items: Array[ResearchItem] = [kettle, continuous, pressure, flash, recirc, concentrate]
	return items
