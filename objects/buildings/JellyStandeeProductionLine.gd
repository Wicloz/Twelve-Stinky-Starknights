class_name JellyStandeeProductionLine
extends FactoryBuilding


func get_display_name() -> String:
	return "Jelly Standee Production Line"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_output_upgrade(
		1, "Rotary Molding Carousel",
		"A spinning mold carousel casts far more standees at once, tripling output.",
		3, {Stockpile.ItemType.FLUID_HARDWARE: 30})]
	return items
