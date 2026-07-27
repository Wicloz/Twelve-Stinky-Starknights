class_name OilRig
extends ExtractionBuilding


func get_display_name() -> String:
	return "Oil Rig"


# Interleaved lattice capped by a controller-run capstone. Fracturing is the one
# upgrade bought almost entirely with bulk primitive sand.
func _upgrade_research() -> Array[ResearchItem]:
	var directional := _yield_upgrade(
		1, "Directional Drilling",
		"Steer the bit off vertical to reach far more of the reservoir from one rig.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 15, Stockpile.ItemType.MECHANICAL_COMPONENTS: 20})
	var top_drive := _speed_upgrade(
		2, "Top Drive",
		"A powered top drive spins pipe continuously instead of stopping to re-set.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 15, Stockpile.ItemType.POWER_CELLS: 8})
	var fracturing := _yield_upgrade(
		1, "Hydraulic Fracturing",
		"Pump in a mountain of sand to prop the fractured rock open and free the flow.",
		2, {Stockpile.ItemType.SAND: 100, Stockpile.ItemType.FLUID_HARDWARE: 15}, [directional, top_drive])
	var managed_pressure := _speed_upgrade(
		2, "Managed-Pressure Drilling",
		"Hold the annulus at pressure so the bit keeps cutting without costly stalls.",
		1.5, {Stockpile.ItemType.ELECTRONIC_ACTUATORS: 8, Stockpile.ItemType.FLUID_HARDWARE: 12}, [directional, top_drive])
	var multilateral := _yield_upgrade(
		3, "Multilateral Wells",
		"Branch a dozen laterals off one bore and drain the whole field through it.",
		2, {
			Stockpile.ItemType.INDUSTRIAL_CONTROLLERS: 4,
			Stockpile.ItemType.ELECTRONIC_ACTUATORS: 10,
			Stockpile.ItemType.FLUID_HARDWARE: 20,
		}, [fracturing, managed_pressure])

	var items: Array[ResearchItem] = [directional, top_drive, fracturing, managed_pressure, multilateral]
	return items
