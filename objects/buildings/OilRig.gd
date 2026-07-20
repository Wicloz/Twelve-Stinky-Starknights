class_name OilRig
extends ExtractionBuilding


func get_display_name() -> String:
	return "Oil Rig"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_yield_upgrade(
		1, "Deeper Drilling",
		"Reach richer reservoirs to pump twice the petrochemicals.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 20})]
	return items
