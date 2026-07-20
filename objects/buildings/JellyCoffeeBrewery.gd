class_name JellyCoffeeBrewery
extends FactoryBuilding


func get_display_name() -> String:
	return "Jelly Coffee Brewery"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_output_upgrade(
		1, "Continuous Brewing Line",
		"A never-ending brew line pours far larger batches, tripling Jelly Coffee output.",
		3, {Stockpile.ItemType.FLUID_HARDWARE: 30})]
	return items
