class_name LoggingCamp
extends ExtractionBuilding


func get_display_name() -> String:
	return "Logging Camp"


func _upgrade_research() -> Array[ResearchItem]:
	# Yield (slot 1) and Speed (slot 2) interleave: each chain's second tier needs
	# the first tier of BOTH, and the capstone converges on the two tops.
	var saws := _yield_upgrade(
		1, "Crosscut Saws",
		"Two-man crosscut saws fell and buck more timber per work party.",
		2, {Stockpile.ItemType.PLANKS: 15})
	var skids := _speed_upgrade(
		2, "Skid Trails",
		"Graded skid trails drag felled logs to the landing faster.",
		1.5, {Stockpile.ItemType.PLANKS: 15})
	var whole_tree := _yield_upgrade(
		1, "Whole-Tree Harvesting",
		"Feller-bunchers take the whole tree at once, yielding far more lumber per cut.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 12}, [saws, skids])
	var winches := _speed_upgrade(
		2, "Powered Winches",
		"Powered cable winches yard the logs in a fraction of the time.",
		1.5, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 12}, [saws, skids])
	var fleet := _yield_upgrade(
		3, "Feller-Buncher Fleet",
		"A full fleet of hydraulic harvesters clears whole stands in one pass.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 8}, [whole_tree, winches])

	var items: Array[ResearchItem] = [saws, skids, whole_tree, winches, fleet]
	return items
