class_name Pitmine
extends ExtractionBuilding


func get_display_name() -> String:
	return "Pitmine"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_yield_upgrade(
		1, "Deeper Excavation",
		"Dig deeper seams to haul up twice as much per dig.",
		2, {Stockpile.ItemType.BRICKS: 20})]
	return items
