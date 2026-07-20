class_name SumatraCoffeeFarm
extends ExtractionBuilding


func get_display_name() -> String:
	return "Sumatra Coffee Farm"


func _upgrade_research() -> Array[ResearchItem]:
	# Yield (slot 1) and Speed (slot 2) interleave, converging on the capstone.
	var cultivars := _yield_upgrade(
		1, "Selective Cultivars",
		"Higher-bearing cultivars set more cherries on every bush.",
		2, {Stockpile.ItemType.PLANKS: 15})
	var irrigation := _speed_upgrade(
		2, "Drip Irrigation",
		"Steady drip irrigation ripens each crop for harvest faster.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 10})
	var terraces := _yield_upgrade(
		1, "Terrace Expansion",
		"Contour terraces put far more hillside under cultivation.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 12}, [cultivars, irrigation])
	var pickers := _speed_upgrade(
		2, "Mechanical Pickers",
		"Straddle-row mechanical pickers strip each terrace in a single pass.",
		1.5, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 15}, [cultivars, irrigation])
	var precision := _yield_upgrade(
		3, "Precision Agriculture",
		"Sensor-guided fertigation pushes every bush to its full yield.",
		2, {Stockpile.ItemType.POWER_CELLS: 6}, [terraces, pickers])

	var items: Array[ResearchItem] = [cultivars, irrigation, terraces, pickers, precision]
	return items


func _get_base_duration() -> float:
	return 1.0


func _get_base_yield_amount() -> int:
	return 1


func get_base_yield_types() -> Array[Stockpile.ItemType]:
	return [Stockpile.ItemType.COFFEE_CHERRIES]
