class_name Brickworks
extends FactoryBuilding


func get_display_name() -> String:
	return "Brickworks"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_output_upgrade(
		1, "Tunnel Kiln",
		"A continuous kiln fires far larger batches, tripling brick output.",
		3, {Stockpile.ItemType.PLANKS: 30})]
	return items
