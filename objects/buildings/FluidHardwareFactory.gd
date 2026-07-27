class_name FluidHardwareFactory
extends FactoryBuilding


func get_display_name() -> String:
	return "Fluid Hardware Factory"


# The only DIVERGENT tree in the colony: everything hangs off one boring mill, and
# from that single root the shop branches three ways -- more capacity, faster
# cutting, or tighter tolerances. Pick an order; you still need the mill first.
func _upgrade_research() -> Array[ResearchItem]:
	# The root (slot 1): you cannot bore a valve body without it.
	var boring := _output_upgrade(
		1, "Horizontal Boring Mill",
		"A heavy boring mill finally lets the shop cut true valve bodies in quantity.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 40, Stockpile.ItemType.CUPRONICKEL_INGOTS: 30})

	# Branch A (slot 1): more finished hardware per run.
	var test_bench := _output_upgrade(
		1, "Hydraulic Test Bench",
		"Proof every casting on a bench plumbed from the shop's own valves, and pass whole batches at once.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 30, Stockpile.ItemType.WATER: 150}, boring)

	# Branch B (slot 2): cut each part faster.
	var turret := _speed_upgrade(
		2, "Turret Lathes",
		"Turret lathes swing tool after tool into the cut without ever re-setting the work.",
		1.5, {Stockpile.ItemType.RAW_TITANIUM: 50, Stockpile.ItemType.MECHANICAL_COMPONENTS: 30}, boring)
	var cnc := _speed_upgrade(
		2, "CNC Machining Centres",
		"Circuit-controlled machining centres run the whole tool path unattended.",
		1.5, {Stockpile.ItemType.INTEGRATED_CIRCUITS: 20, Stockpile.ItemType.ELECTRONIC_ACTUATORS: 8}, turret)

	# Branch C (slot 3): waste less cupronickel on rejects.
	var lapping := _efficiency_upgrade(
		3, "Precision Lapping",
		"Lap every seat with abrasive grit until it seals, and almost nothing is scrapped.",
		1.5, {Stockpile.ItemType.SAND: 80}, boring)
	var seals := _efficiency_upgrade(
		3, "Elastomer Seals",
		"Moulded seals do the sealing instead of the metal, so tolerances stop eating stock.",
		1.5, {Stockpile.ItemType.PLASTIC: 40, Stockpile.ItemType.ACRYLIC: 30}, lapping)

	var items: Array[ResearchItem] = [boring, test_bench, turret, cnc, lapping, seals]
	return items
