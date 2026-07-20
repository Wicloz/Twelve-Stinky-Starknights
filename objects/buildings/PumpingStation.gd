class_name PumpingStation
extends ExtractionBuilding


func get_display_name() -> String:
	return "Pumping Station"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_yield_upgrade(
		1, "High-Volume Pumps",
		"Bigger impellers draw twice the water per cycle.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 20})]
	return items
