class_name PumpingStation
extends ExtractionBuilding


func get_display_name() -> String:
	return "Pumping Station"


# Interleaved lattice with no capstone: the well field is mostly a great deal of
# brick lining sunk into the ground, while speed climbs to actuators and cells.
func _upgrade_research() -> Array[ResearchItem]:
	var intake := _yield_upgrade(
		1, "Wider Intake",
		"A broad cupronickel screen resists the brine and draws more water each stroke.",
		2, {Stockpile.ItemType.CUPRONICKEL_INGOTS: 20})
	var boosters := _speed_upgrade(
		2, "Booster Pumps",
		"In-line booster pumps push each cycle through the mains faster.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 15, Stockpile.ItemType.MECHANICAL_COMPONENTS: 18})
	var wellfield := _yield_upgrade(
		1, "Deep Well Field",
		"Sink and brick-case a whole field of deep wells to tap far more of the aquifer.",
		2, {Stockpile.ItemType.BRICKS: 120, Stockpile.ItemType.FLUID_HARDWARE: 18}, [intake, boosters])
	var turbopumps := _speed_upgrade(
		2, "High-Head Turbopumps",
		"High-head turbopumps lift each batch of water in seconds.",
		1.5, {Stockpile.ItemType.ELECTRONIC_ACTUATORS: 8, Stockpile.ItemType.POWER_CELLS: 8}, [intake, boosters])

	var items: Array[ResearchItem] = [intake, boosters, wellfield, turbopumps]
	return items
