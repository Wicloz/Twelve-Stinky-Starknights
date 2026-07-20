class_name Pitmine
extends ExtractionBuilding


func get_display_name() -> String:
	return "Pitmine"


func _upgrade_research() -> Array[ResearchItem]:
	# Yield (slot 1) and Speed (slot 2) interleave, converging on the capstone.
	var pit := _yield_upgrade(
		1, "Wider Pit",
		"Shore up and widen the pit walls to work more ore at each level.",
		2, {Stockpile.ItemType.BRICKS: 15})
	var hoist := _speed_upgrade(
		2, "Powered Hoist",
		"A powered hoist lifts each skip of ore out far faster.",
		1.5, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 12})
	var benches := _yield_upgrade(
		1, "Bench Blasting",
		"Drill-and-blast benches shatter and expose far more ore per round.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 15}, [pit, hoist])
	var trucks := _speed_upgrade(
		2, "Haul Trucks",
		"Hydraulic haul trucks clear the muck pile between rounds much faster.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 10}, [pit, hoist])
	var bucketwheel := _yield_upgrade(
		3, "Bucket-Wheel Excavator",
		"A continuous bucket-wheel excavator tears through the whole face at once.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 12}, [benches, trucks])

	var items: Array[ResearchItem] = [pit, hoist, benches, trucks, bucketwheel]
	return items
