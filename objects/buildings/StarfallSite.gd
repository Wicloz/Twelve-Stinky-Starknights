class_name StarfallSite
extends ExtractionBuilding


func get_display_name() -> String:
	return "Starfall Extraction Site"


# The most advanced site: it starts where the others end. Every step is electro-
# mechanical or better, and the capstone is the richest in the colony.
func _upgrade_research() -> Array[ResearchItem]:
	var array := _yield_upgrade(
		1, "Wider Collection Array",
		"A broader collection array sweeps up more hoshiumium from each fall.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 50})
	var drones := _speed_upgrade(
		2, "Recovery Drones",
		"A swarm of autonomous drones recovers the scattered fragments far faster.",
		1.5, {
			Stockpile.ItemType.ELECTRONIC_ACTUATORS: 25,
			Stockpile.ItemType.POWER_CELLS: 25,
			Stockpile.ItemType.ELECTRONIC_COMPONENTS: 30,
		})
	var crater := _yield_upgrade(
		1, "Deep-Crater Excavation",
		"Dig the impact craters right out to reach the far richer buried hoshiumium.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 60, Stockpile.ItemType.FLUID_HARDWARE: 6}, [array, drones])
	var separators := _speed_upgrade(
		2, "Magnetic Separators",
		"Heavy electrum windings pull the ore clear of the slag the moment it is lifted.",
		1.5, {Stockpile.ItemType.ELECTRUM_WIRE: 120}, [array, drones])
	var grid := _yield_upgrade(
		3, "Starfall Refinery Grid",
		"A site-wide refinery grid wrings every last gram of hoshiumium out of the fall.",
		2, {
			Stockpile.ItemType.INDUSTRIAL_CONTROLLERS: 15,
			Stockpile.ItemType.ELECTRONIC_COMPONENTS: 60,
			Stockpile.ItemType.POWER_CELLS: 30,
		}, [crater, separators])

	var items: Array[ResearchItem] = [array, drones, crater, separators, grid]
	return items
