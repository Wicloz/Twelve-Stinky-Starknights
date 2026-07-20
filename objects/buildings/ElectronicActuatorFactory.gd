class_name ElectronicActuatorFactory
extends FactoryBuilding


func get_display_name() -> String:
	return "Electronic Actuator Factory"


func _upgrade_research() -> Array[ResearchItem]:
	var items: Array[ResearchItem] = [_output_upgrade(
		1, "Parallel Assembly Bays",
		"Twin assembly bays double the actuators built per run.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 20})]
	return items
