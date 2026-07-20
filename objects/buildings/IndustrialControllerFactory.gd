class_name IndustrialControllerFactory
extends FactoryBuilding


func get_display_name() -> String:
	return "Industrial Computer Module Plant"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_output_upgrade(
		1, "Panel Assembly Jig",
		"A batch jig doubles the computer modules built per run.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 20})]
	return items
