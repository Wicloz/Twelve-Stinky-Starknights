class_name BrassFurnace
extends FactoryBuilding


func get_display_name() -> String:
	return "Brass Foundry"


# Three chains that all converge on a late capstone: the foundry stays a primitive
# brick-and-clay affair until power cells let it run a continuous melt.
func _upgrade_research() -> Array[ResearchItem]:
	# Output chain (slot 1): melt a bigger charge of brass per heat.
	var crucible := _output_upgrade(
		1, "Larger Crucible",
		"Throw a bigger clay-graphite crucible to melt more raw brass per heat.",
		2, {Stockpile.ItemType.CLAY: 50})
	var reverberatory := _output_upgrade(
		1, "Reverberatory Furnace",
		"A brick-vaulted reverberatory furnace smelts far larger charges at once.",
		2, {Stockpile.ItemType.BRICKS: 150, Stockpile.ItemType.MECHANICAL_COMPONENTS: 15}, crucible)

	# Speed chain (slot 2): reach pouring temperature faster.
	var burners := _speed_upgrade(
		2, "Regenerative Burners",
		"Brick regenerators recycle flue heat into the blast, smelting faster.",
		1.5, {Stockpile.ItemType.BRICKS: 80, Stockpile.ItemType.PLANKS: 25})
	var oxygen := _speed_upgrade(
		2, "Oxygen Enrichment",
		"Piping oxygen into the blast drives each heat to temperature faster still.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 15, Stockpile.ItemType.MECHANICAL_COMPONENTS: 12}, burners)

	# Efficiency chain (slot 3): recover metal that would be lost to slag.
	var flux := _efficiency_upgrade(
		3, "Fluxing Practice",
		"A silica flux cover controls the slag and keeps more brass out of the dross.",
		1.5, {Stockpile.ItemType.SAND: 40})
	var reclaim := _efficiency_upgrade(
		3, "Slag Reclamation",
		"Leach the cold slag in spent battery acid to win back every entrained bead of metal.",
		1.5, {Stockpile.ItemType.BATTERY_ACID: 20, Stockpile.ItemType.MECHANICAL_COMPONENTS: 20}, flux)

	# Capstone (slot 4): all three chains converge -- bulk brick plus real power.
	var melt_line := _output_upgrade(
		4, "Continuous Melt Line",
		"Tap the furnace without ever letting it cool, doubling output again.",
		2, {Stockpile.ItemType.BRICKS: 200, Stockpile.ItemType.POWER_CELLS: 10},
		[reverberatory, oxygen, reclaim])

	var items: Array[ResearchItem] = [crucible, reverberatory, burners, oxygen, flux, reclaim, melt_line]
	return items
