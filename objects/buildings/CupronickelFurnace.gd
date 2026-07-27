class_name CupronickelFurnace
extends FactoryBuilding


func get_display_name() -> String:
	return "Cupronickel Foundry"


# Deliberately lopsided: a cheap primitive start, then a big ELECTRO-MECHANICAL
# spike (the induction furnace needs coil wire and power cells) on an otherwise
# early building. Only one efficiency step, and no capstone.
func _upgrade_research() -> Array[ResearchItem]:
	# Output chain (slot 1): melt a bigger charge of cupronickel per heat.
	var crucible := _output_upgrade(
		1, "Larger Crucible",
		"Throw a bigger crucible and set it in a brick hearth to melt more ore per heat.",
		2, {Stockpile.ItemType.CLAY: 50, Stockpile.ItemType.BRICKS: 40})
	var induction := _output_upgrade(
		1, "Induction Furnace",
		"Wind a heavy electrum coil and melt the charge by induction, with no fire at all.",
		2, {Stockpile.ItemType.ELECTRUM_WIRE: 90, Stockpile.ItemType.POWER_CELLS: 30}, crucible)

	# Speed chain (slot 2): drive the melt and pour faster.
	var blast := _speed_upgrade(
		2, "Oxygen-Enriched Blast",
		"Enrich the furnace blast with oxygen to smelt each heat faster.",
		1.5, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 40, Stockpile.ItemType.BRICKS: 60})
	var casting := _speed_upgrade(
		2, "Continuous Casting",
		"Withdraw a continuous strand through a water-cooled cupronickel mould instead of pouring pigs.",
		1.5, {Stockpile.ItemType.CUPRONICKEL_INGOTS: 75, Stockpile.ItemType.FLUID_HARDWARE: 8}, blast)

	# Efficiency (slot 3): a single step -- blanket the melt so it stops burning away.
	var atmosphere := _efficiency_upgrade(
		3, "Controlled Atmosphere",
		"Flood the furnace with inert petrochemical gas so far less cupronickel oxidises away.",
		1.5, {Stockpile.ItemType.PETROCHEMICALS: 120})

	var items: Array[ResearchItem] = [crucible, induction, blast, casting, atmosphere]
	return items
