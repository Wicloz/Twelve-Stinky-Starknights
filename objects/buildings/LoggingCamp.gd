class_name LoggingCamp
extends ExtractionBuilding


func get_display_name() -> String:
	return "Logging Camp"


# The humblest site in the colony: a short interleaved lattice that never climbs
# past fluid hardware, and no capstone at all. Two single-material starters.
func _upgrade_research() -> Array[ResearchItem]:
	var saws := _yield_upgrade(
		1, "Crosscut Saws",
		"Brass-toothed crosscut saws fell and buck far more timber per work party.",
		2, {Stockpile.ItemType.BRASS_INGOTS: 15})
	var skids := _speed_upgrade(
		2, "Skid Trails",
		"Corduroy the ground with planks so logs slide to the landing quickly.",
		1.5, {Stockpile.ItemType.PLANKS: 30})
	var whole_tree := _yield_upgrade(
		1, "Whole-Tree Harvesting",
		"Hydraulic feller-bunchers take the whole tree at once, stem and crown together.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 40, Stockpile.ItemType.FLUID_HARDWARE: 5}, [saws, skids])
	var winches := _speed_upgrade(
		2, "Powered Winches",
		"Brass-drummed cable winches yard the logs in a fraction of the time.",
		1.5, {Stockpile.ItemType.BRASS_INGOTS: 25, Stockpile.ItemType.MECHANICAL_COMPONENTS: 30}, [saws, skids])

	var items: Array[ResearchItem] = [saws, skids, whole_tree, winches]
	return items
