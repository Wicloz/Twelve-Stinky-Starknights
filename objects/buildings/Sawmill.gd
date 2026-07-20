class_name Sawmill
extends FactoryBuilding


func get_display_name() -> String:
	return "Sawmill"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_output_upgrade(
		1, "Twin-Blade Headsaw",
		"A second blade doubles the planks cut from every log.",
		2, {Stockpile.ItemType.BRICKS: 20})]
	return items
