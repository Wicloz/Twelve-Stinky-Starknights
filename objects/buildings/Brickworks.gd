class_name Brickworks
extends FactoryBuilding


func get_display_name() -> String:
	return "Brickworks"


func _upgrade_research() -> Array[ResearchItem]:
	var bigger := _output_upgrade(
		1, "Bigger Kiln",
		"Fire more clay per batch, doubling brick output.",
		2, {Stockpile.ItemType.PLANKS: 20})

	var tunnel := _output_upgrade(
		2, "Tunnel Kiln",
		"A continuous kiln bakes even larger brick batches.",
		3, {Stockpile.ItemType.PLANKS: 50}, bigger)

	var forced_air := _speed_upgrade(
		3, "Forced-Air Firing",
		"Blast the kiln hotter to fire each batch twice as fast.",
		2.0, {Stockpile.ItemType.PLANKS: 30})

	var items: Array[ResearchItem] = [bigger, tunnel, forced_air]
	return items
