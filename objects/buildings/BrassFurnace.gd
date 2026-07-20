class_name BrassFurnace
extends FactoryBuilding


func get_display_name() -> String:
	return "Brass Foundry"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_output_upgrade(
		1, "Regenerative Burners",
		"Recycle furnace heat to smelt twice the brass per charge.",
		2, {Stockpile.ItemType.BRICKS: 20})]
	return items
