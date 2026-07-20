class_name MechanicalComponentFactory
extends FactoryBuilding


func get_display_name() -> String:
	return "Mechanical Component Factory"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_output_upgrade(
		1, "Hydraulic Press Line",
		"Stamp out twice the mechanical components per run.",
		2, {Stockpile.ItemType.BRICKS: 20})]
	return items
