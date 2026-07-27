class_name Pitmine
extends ExtractionBuilding


func get_display_name() -> String:
	return "Pitmine"


# Interleaved lattice: each chain's second tier needs the first tier of BOTH, and
# the capstone converges on the two tops. Costs run on primitive bulk (timber,
# blasting acid, fuel) before the excavator finally demands power cells.
func _upgrade_research() -> Array[ResearchItem]:
	var pit := _yield_upgrade(
		1, "Wider Pit",
		"Timber the walls and widen the pit to work more ore at every level.",
		2, {Stockpile.ItemType.PLANKS: 40})
	var hoist := _speed_upgrade(
		2, "Powered Hoist",
		"A brass-geared hoist lifts each skip of ore out far faster.",
		1.5, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 30, Stockpile.ItemType.BRASS_INGOTS: 20})
	var benches := _yield_upgrade(
		1, "Bench Blasting",
		"Nitrate the charges in spent acid and shoot the face in benches, exposing far more ore.",
		2, {Stockpile.ItemType.BATTERY_ACID: 75, Stockpile.ItemType.MECHANICAL_COMPONENTS: 30}, [pit, hoist])
	var trucks := _speed_upgrade(
		2, "Haul Trucks",
		"A thirsty fleet of haul trucks clears the muck pile between rounds.",
		1.5, {Stockpile.ItemType.PETROCHEMICALS: 180, Stockpile.ItemType.FLUID_HARDWARE: 8}, [pit, hoist])
	var bucketwheel := _yield_upgrade(
		3, "Bucket-Wheel Excavator",
		"One continuous bucket-wheel chews through the entire face without stopping.",
		2, {
			Stockpile.ItemType.MECHANICAL_COMPONENTS: 80,
			Stockpile.ItemType.FLUID_HARDWARE: 8,
			Stockpile.ItemType.POWER_CELLS: 35,
		}, [benches, trucks])

	var items: Array[ResearchItem] = [pit, hoist, benches, trucks, bucketwheel]
	return items
