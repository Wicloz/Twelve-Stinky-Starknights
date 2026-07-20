class_name JellyStandeeProductionLine
extends FactoryBuilding


func get_display_name() -> String:
	return "Jelly Standee Production Line"


func _upgrade_research() -> Array[ResearchItem]:
	var molds := _output_upgrade(
		1, "Multi-Cavity Molds",
		"Cast several standees at once, doubling output.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 20})

	var carousel := _output_upgrade(
		2, "Rotary Molding Carousel",
		"A spinning mold carousel turns out even larger batches.",
		3, {Stockpile.ItemType.FLUID_HARDWARE: 50}, molds)

	var uv := _speed_upgrade(
		3, "Rapid UV Curing",
		"Flash-cure the resin to release each batch twice as fast.",
		2.0, {Stockpile.ItemType.FLUID_HARDWARE: 30})

	var items: Array[ResearchItem] = [molds, carousel, uv]
	return items
