class_name SumatraCoffeeFarm
extends ExtractionBuilding


func get_display_name() -> String:
	return "Sumatra Coffee Farm"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_yield_upgrade(
		1, "Denser Planting",
		"Intercropped rows double the cherries picked per harvest.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 20})]
	return items


func _determine_harvest() -> void:
	_will_harvest[Stockpile.ItemType.COFFEE_CHERRIES] = _get_yield_scale()
