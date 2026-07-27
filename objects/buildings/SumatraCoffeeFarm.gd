class_name SumatraCoffeeFarm
extends ExtractionBuilding


func get_display_name() -> String:
	return "Sumatra Coffee Farm"


# The only site with two entirely INDEPENDENT chains -- planting and picking never
# depend on one another, so the farm can be pushed lopsidedly either way. A long
# three-step yield chain climbs from timber to sensors; speed stays short.
func _upgrade_research() -> Array[ResearchItem]:
	# Yield chain (slot 1): more cherries on every bush.
	var cultivars := _yield_upgrade(
		1, "Selective Cultivars",
		"Raise higher-bearing seedlings under plank shade frames.",
		2, {Stockpile.ItemType.PLANKS: 20})
	var terraces := _yield_upgrade(
		1, "Terrace Expansion",
		"Cut brick-walled contour terraces to put far more hillside under cultivation.",
		2, {Stockpile.ItemType.BRICKS: 100, Stockpile.ItemType.PLANKS: 40}, cultivars)
	var precision := _yield_upgrade(
		1, "Precision Agriculture",
		"Sensor-guided fertigation pushes every bush on the hill to its full yield.",
		2, {Stockpile.ItemType.ELECTRONIC_COMPONENTS: 15, Stockpile.ItemType.POWER_CELLS: 6}, terraces)

	# Speed chain (slot 2): bring each crop in sooner.
	var irrigation := _speed_upgrade(
		2, "Drip Irrigation",
		"Plastic drip lines water every row, ripening each crop for harvest faster.",
		1.5, {Stockpile.ItemType.PLASTIC: 25, Stockpile.ItemType.FLUID_HARDWARE: 10})
	var pickers := _speed_upgrade(
		2, "Mechanical Pickers",
		"Straddle-row pickers strip an entire terrace in a single pass.",
		1.5, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 20, Stockpile.ItemType.FLUID_HARDWARE: 12}, irrigation)

	var items: Array[ResearchItem] = [cultivars, terraces, precision, irrigation, pickers]
	return items


func _get_base_duration() -> float:
	return 1.0


func _get_base_yield_amount() -> int:
	return 1


func get_base_yield_types() -> Array[Stockpile.ItemType]:
	return [Stockpile.ItemType.COFFEE_CHERRIES]
