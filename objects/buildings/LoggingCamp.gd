class_name LoggingCamp
extends ExtractionBuilding


func get_display_name() -> String:
	return "Logging Camp"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_yield_upgrade(
		1, "Mechanized Felling",
		"Chainsaws and skidders double the lumber cut per trip.",
		2, {Stockpile.ItemType.BRICKS: 20})]
	return items
