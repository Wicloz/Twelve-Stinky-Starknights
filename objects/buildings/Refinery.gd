class_name Refinery
extends FactoryBuilding


func get_display_name() -> String:
	return "Petrochemical Refinery"


# A process plant: it is largely built from its own products (plastic seals and
# liners) and fed on bulk silica catalyst, capped by a controller-run complex.
func _upgrade_research() -> Array[ResearchItem]:
	# Output chain (slot 1): run more feedstock into acrylic and plastic per pass.
	var column := _output_upgrade(
		1, "Extra Cracking Column",
		"Raise another brick-lined cracking column to process more petrochemicals per run.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 8, Stockpile.ItemType.BRICKS: 60})
	var cracker := _output_upgrade(
		1, "Fluid Catalytic Cracker",
		"A fluidised bed of silica catalyst cracks heavy feedstock into far more product.",
		2, {Stockpile.ItemType.SAND: 80, Stockpile.ItemType.FLUID_HARDWARE: 8}, column)

	# Speed chain (slot 2): turn each batch around faster.
	var vacuum := _speed_upgrade(
		2, "Vacuum Distillation",
		"Pull the heavy fractions over under vacuum to complete each run faster.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 7, Stockpile.ItemType.MECHANICAL_COMPONENTS: 40})
	var integrated := _speed_upgrade(
		2, "Heat-Integrated Columns",
		"Cupronickel exchangers cross-feed heat between columns, reaching cut point sooner.",
		1.5, {Stockpile.ItemType.CUPRONICKEL_INGOTS: 90}, vacuum)

	# Efficiency chain (slot 3): wring more product from every barrel of feedstock.
	var catalyst := _efficiency_upgrade(
		3, "Catalyst Recovery",
		"Wash and reburn the spent catalyst in acid so less feedstock leaves as coke.",
		1.5, {Stockpile.ItemType.SAND: 60, Stockpile.ItemType.BATTERY_ACID: 60})
	var closed_loop := _efficiency_upgrade(
		3, "Closed-Loop Cracking",
		"Plastic-lined recycle lines return unconverted fractions to the cracker.",
		1.5, {Stockpile.ItemType.PLASTIC: 120, Stockpile.ItemType.ELECTRONIC_ACTUATORS: 25}, catalyst)

	# Capstone (slot 4): the whole plant under one controller.
	var complex := _output_upgrade(
		4, "Integrated Petrochemical Complex",
		"Run every column from one control room and double the plant's throughput again.",
		2, {Stockpile.ItemType.INDUSTRIAL_CONTROLLERS: 18, Stockpile.ItemType.FLUID_HARDWARE: 16},
		[cracker, integrated, closed_loop])

	var items: Array[ResearchItem] = [column, cracker, vacuum, integrated, catalyst, closed_loop, complex]
	return items
