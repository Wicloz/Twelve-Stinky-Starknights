class_name JellyCoffeeBrewery
extends FactoryBuilding


func get_display_name() -> String:
	return "Jelly Coffee Brewery"


# Food plant: copper-alloy vessels and a great deal of water. Its capstone is the
# only one that buys SPEED rather than output -- Jelly needs the stuff poured fast.
func _upgrade_research() -> Array[ResearchItem]:
	# Output chain (slot 1): brew a bigger batch each cycle.
	var kettle := _output_upgrade(
		1, "Bigger Brew Kettle",
		"Beat out a far larger cupronickel kettle to brew more cherries at once.",
		2, {Stockpile.ItemType.CUPRONICKEL_INGOTS: 25})
	var continuous := _output_upgrade(
		1, "Continuous Brewing Line",
		"A continuous-flow line never stops pouring, doubling the batch again.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 20, Stockpile.ItemType.MECHANICAL_COMPONENTS: 20}, kettle)

	# Speed chain (slot 2): pull the extraction faster.
	var pressure := _speed_upgrade(
		2, "Pressure Brewing",
		"Force the water through under pressure to extract each batch faster.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 18, Stockpile.ItemType.CUPRONICKEL_INGOTS: 15})
	var flash := _speed_upgrade(
		2, "Flash Extraction",
		"Flash-heat the slurry and extract in seconds rather than minutes.",
		1.5, {Stockpile.ItemType.ELECTRONIC_ACTUATORS: 8, Stockpile.ItemType.POWER_CELLS: 8}, pressure)

	# Efficiency chain (slot 3): get more coffee from every cherry.
	var recirc := _efficiency_upgrade(
		3, "Grounds Recirculation",
		"Flood the spent grounds with water again and again to pull every last drop from them.",
		1.5, {Stockpile.ItemType.WATER: 150, Stockpile.ItemType.MECHANICAL_COMPONENTS: 20})
	var concentrate := _efficiency_upgrade(
		3, "Cold-Brew Concentration",
		"A slow chilled steep concentrates the yield, sipping far fewer cherries.",
		1.5, {Stockpile.ItemType.POWER_CELLS: 10, Stockpile.ItemType.PLASTIC: 25}, recirc)

	# Capstone (slot 4): the only capstone that buys SPEED.
	var control_suite := _speed_upgrade(
		4, "Roastery Control Suite",
		"Hand the whole roastery to a controller and it never misses a beat.",
		1.5, {Stockpile.ItemType.INDUSTRIAL_CONTROLLERS: 5, Stockpile.ItemType.ELECTRONIC_COMPONENTS: 20},
		[continuous, flash, concentrate])

	var items: Array[ResearchItem] = [kettle, continuous, pressure, flash, recirc, concentrate, control_suite]
	return items
