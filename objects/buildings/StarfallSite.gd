class_name StarfallSite
extends ExtractionBuilding


func get_display_name() -> String:
	return "Starfall Extraction Site"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_yield_upgrade(
		1, "Wider Collection Array",
		"A broader collector doubles the Hoshiumium recovered per pass.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 20})]
	return items


func can_demolish() -> bool:
	return false
