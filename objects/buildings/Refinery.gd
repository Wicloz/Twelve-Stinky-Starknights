class_name Refinery
extends FactoryBuilding


func get_display_name() -> String:
	return "Petrochemical Refinery"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_output_upgrade(
		1, "Catalytic Reformer",
		"Process far more petrochemicals per run, tripling plastic (and acrylic) output.",
		3, {Stockpile.ItemType.FLUID_HARDWARE: 30})]
	return items
