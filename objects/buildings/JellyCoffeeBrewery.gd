class_name JellyCoffeeBrewery
extends FactoryBuilding


func get_display_name() -> String:
	return "Jelly Coffee Brewery"


func _upgrade_research() -> Array[ResearchItem]:
	var kettle := _output_upgrade(
		1, "Bigger Brew Kettle",
		"Brew more cherries per batch, doubling Jelly Coffee output.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 20})

	var continuous := _output_upgrade(
		2, "Continuous Brewing Line",
		"A never-ending brew line pours even larger batches.",
		3, {Stockpile.ItemType.FLUID_HARDWARE: 50}, kettle)

	var flash := _speed_upgrade(
		3, "Flash Brewing",
		"Superheat the brew to finish each batch twice as fast.",
		2.0, {Stockpile.ItemType.FLUID_HARDWARE: 30})

	var items: Array[ResearchItem] = [kettle, continuous, flash]
	return items
