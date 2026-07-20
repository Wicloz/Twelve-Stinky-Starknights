class_name WireMill
extends FactoryBuilding


func get_display_name() -> String:
	return "Electrum Wire Mill"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_output_upgrade(
		1, "Multi-Die Drawing",
		"Draw several wires in parallel, doubling wire output.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 20})]
	return items
