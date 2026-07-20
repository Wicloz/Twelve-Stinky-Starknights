class_name BrassFurnace
extends FactoryBuilding


func get_display_name() -> String:
	return "Brass Foundry"


func _upgrade_research() -> Array[ResearchItem]:
	# Output chain (slot 1): melt a bigger charge of brass per heat.
	var crucible := _output_upgrade(
		1, "Larger Crucible",
		"Reline a larger crucible in refractory brick to melt more raw brass per heat.",
		2, {Stockpile.ItemType.BRICKS: 15})
	var reverberatory := _output_upgrade(
		1, "Reverberatory Furnace",
		"A brick-lined reverberatory furnace smelts far larger charges at once.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 15}, crucible)

	# Speed chain (slot 2): reach pouring temperature faster.
	var burners := _speed_upgrade(
		2, "Regenerative Burners",
		"Regenerative burners recycle flue heat to preheat the blast, smelting faster.",
		1.5, {Stockpile.ItemType.PLANKS: 20})
	var oxygen := _speed_upgrade(
		2, "Oxygen Enrichment",
		"Enriching the blast with oxygen drives each heat to temperature faster still.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 10}, burners)

	# Efficiency chain (slot 3): recover metal that would be lost to slag.
	var flux := _efficiency_upgrade(
		3, "Fluxing Practice",
		"A proper flux cover controls the slag and keeps more brass out of the dross.",
		1.5, {Stockpile.ItemType.BRICKS: 15})
	var reclaim := _efficiency_upgrade(
		3, "Slag Reclamation",
		"Reprocess the slag to reclaim entrained metal, wasting far less raw brass.",
		1.5, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 15}, flux)

	var items: Array[ResearchItem] = [crucible, reverberatory, burners, oxygen, flux, reclaim]
	return items
