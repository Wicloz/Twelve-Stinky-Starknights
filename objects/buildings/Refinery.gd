class_name Refinery
extends FactoryBuilding


func get_display_name() -> String:
	return "Petrochemical Refinery"


func _upgrade_research() -> Array[ResearchItem]:
	var column := _output_upgrade(
		1, "Extra Cracking Column",
		"Process more petrochemicals per run, doubling plastic (and acrylic) output.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 20})

	var reformer := _output_upgrade(
		2, "Catalytic Reformer",
		"Squeeze even larger batches out of every run.",
		3, {Stockpile.ItemType.FLUID_HARDWARE: 50}, column)

	var vacuum := _speed_upgrade(
		3, "Vacuum Distillation",
		"Distill under vacuum to complete each run twice as fast.",
		2.0, {Stockpile.ItemType.FLUID_HARDWARE: 30})

	var items: Array[ResearchItem] = [column, reformer, vacuum]
	return items
