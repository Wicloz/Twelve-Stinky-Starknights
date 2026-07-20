class_name StarfallSite
extends ExtractionBuilding


func get_display_name() -> String:
	return "Starfall Extraction Site"


func _upgrade_research() -> Array[ResearchItem]:
	# Yield (slot 1) and Speed (slot 2) interleave, converging on the capstone.
	var array := _yield_upgrade(
		1, "Wider Collection Array",
		"A broader collection array sweeps up more hoshiumium from each fall.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 12})
	var drones := _speed_upgrade(
		2, "Recovery Drones",
		"Autonomous drones recover the scattered fragments far faster.",
		1.5, {Stockpile.ItemType.ELECTRONIC_ACTUATORS: 6})
	var crater := _yield_upgrade(
		1, "Deep-Crater Excavation",
		"Digging out the impact craters reaches far richer buried hoshiumium.",
		2, {Stockpile.ItemType.POWER_CELLS: 6}, [array, drones])
	var separators := _speed_upgrade(
		2, "Magnetic Separators",
		"Magnetic separators sort ore from slag the moment it is recovered.",
		1.5, {Stockpile.ItemType.ELECTRONIC_ACTUATORS: 8}, [array, drones])
	var grid := _yield_upgrade(
		3, "Starfall Refinery Grid",
		"A site-wide refinery grid wrings every gram of hoshiumium from the fall.",
		2, {Stockpile.ItemType.INDUSTRIAL_CONTROLLERS: 4}, [crater, separators])

	var items: Array[ResearchItem] = [array, drones, crater, separators, grid]
	return items


func can_demolish() -> bool:
	return false
