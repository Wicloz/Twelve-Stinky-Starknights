class_name CupronickelFurnace
extends FactoryBuilding


func get_display_name() -> String:
	return "Cupronickel Foundry"


func _upgrade_research() -> Array[ResearchItem]:
	# Output chain (slot 1): melt a bigger charge of cupronickel per heat.
	var crucible := _output_upgrade(
		1, "Larger Crucible",
		"Reline a larger crucible in refractory brick to melt more raw cupronickel per heat.",
		2, {Stockpile.ItemType.BRICKS: 15})
	var induction := _output_upgrade(
		1, "Induction Furnace",
		"A refractory-lined induction furnace melts far larger charges at once.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 15}, crucible)

	# Speed chain (slot 2): drive the melt and pour faster.
	var blast := _speed_upgrade(
		2, "Oxygen-Enriched Blast",
		"Enrich the furnace blast with oxygen to smelt each heat faster.",
		1.5, {Stockpile.ItemType.PLANKS: 20})
	var casting := _speed_upgrade(
		2, "Continuous Casting",
		"Cast ingots in a continuous strand instead of moulds, clearing each heat faster still.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 10}, blast)

	# Efficiency chain (slot 3): lose less cupronickel to oxidation and slag.
	var atmosphere := _efficiency_upgrade(
		3, "Controlled Atmosphere",
		"Smelt under a protective atmosphere so less cupronickel oxidises away.",
		1.5, {Stockpile.ItemType.BRICKS: 15})
	var reclaim := _efficiency_upgrade(
		3, "Slag Reclamation",
		"Reprocess the slag to reclaim entrained metal, wasting far less raw cupronickel.",
		1.5, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 15}, atmosphere)

	var items: Array[ResearchItem] = [crucible, induction, blast, casting, atmosphere, reclaim]
	return items
