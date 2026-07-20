class_name PumpingStation
extends ExtractionBuilding


func get_display_name() -> String:
	return "Pumping Station"


func _upgrade_research() -> Array[ResearchItem]:
	# Yield (slot 1) and Speed (slot 2) interleave, converging on the capstone.
	var intake := _yield_upgrade(
		1, "Wider Intake",
		"A wider screened intake draws more water on every stroke.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 12})
	var boosters := _speed_upgrade(
		2, "Booster Pumps",
		"In-line booster pumps push each cycle through faster.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 12})
	var wellfield := _yield_upgrade(
		1, "Deep Well Field",
		"A field of deep wells taps far more of the aquifer at once.",
		2, {Stockpile.ItemType.POWER_CELLS: 6}, [intake, boosters])
	var turbopumps := _speed_upgrade(
		2, "High-Head Turbopumps",
		"High-head turbopumps move each batch of water in seconds.",
		1.5, {Stockpile.ItemType.ELECTRONIC_ACTUATORS: 6}, [intake, boosters])
	var manifold := _yield_upgrade(
		3, "Aquifer Manifold",
		"A manifold ganging every well draws the whole field in one pull.",
		2, {Stockpile.ItemType.POWER_CELLS: 8}, [wellfield, turbopumps])

	var items: Array[ResearchItem] = [intake, boosters, wellfield, turbopumps, manifold]
	return items
