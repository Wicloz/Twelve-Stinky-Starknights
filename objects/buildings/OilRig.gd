class_name OilRig
extends ExtractionBuilding


func get_display_name() -> String:
	return "Oil Rig"


func _upgrade_research() -> Array[ResearchItem]:
	# Yield (slot 1) and Speed (slot 2) interleave, converging on the capstone.
	var directional := _yield_upgrade(
		1, "Directional Drilling",
		"Directional wells reach more of the reservoir from a single rig.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 12})
	var top_drive := _speed_upgrade(
		2, "Top Drive",
		"A top-drive system spins pipe continuously, drilling each stand faster.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 12})
	var fracturing := _yield_upgrade(
		1, "Hydraulic Fracturing",
		"Fracturing the formation opens far greater flow from every well.",
		2, {Stockpile.ItemType.POWER_CELLS: 6}, [directional, top_drive])
	var managed_pressure := _speed_upgrade(
		2, "Managed-Pressure Drilling",
		"Managed-pressure drilling keeps the bit cutting without costly stalls.",
		1.5, {Stockpile.ItemType.ELECTRONIC_ACTUATORS: 6}, [directional, top_drive])
	var multilateral := _yield_upgrade(
		3, "Multilateral Wells",
		"Branching multilateral wells drain the whole field through one bore.",
		2, {Stockpile.ItemType.INDUSTRIAL_CONTROLLERS: 4}, [fracturing, managed_pressure])

	var items: Array[ResearchItem] = [directional, top_drive, fracturing, managed_pressure, multilateral]
	return items
