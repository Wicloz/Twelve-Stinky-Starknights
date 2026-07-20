class_name Refinery
extends FactoryBuilding


func get_display_name() -> String:
	return "Petrochemical Refinery"


func _upgrade_research() -> Array[ResearchItem]:
	# Output chain (slot 1): run more feedstock into acrylic and plastic per pass.
	var column := _output_upgrade(
		1, "Extra Cracking Column",
		"Add a cracking column to process more petrochemicals per run.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 15})
	var cracker := _output_upgrade(
		1, "Fluid Catalytic Cracker",
		"Fluid catalytic cracking breaks heavier feedstock into far more product per run.",
		2, {Stockpile.ItemType.POWER_CELLS: 8}, column)

	# Speed chain (slot 2): turn each batch around faster.
	var vacuum := _speed_upgrade(
		2, "Vacuum Distillation",
		"Distil the heavy fractions under vacuum to complete each run faster.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 15})
	var integrated := _speed_upgrade(
		2, "Heat-Integrated Columns",
		"Cross-exchange heat between columns so each run reaches cut point faster still.",
		1.5, {Stockpile.ItemType.ELECTRONIC_ACTUATORS: 8}, vacuum)

	# Efficiency chain (slot 3): wring more product from every barrel of feedstock.
	var catalyst := _efficiency_upgrade(
		3, "Catalyst Recovery",
		"Regenerate and recycle the catalyst so less petrochemical feedstock is wasted.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 15})
	var closed_loop := _efficiency_upgrade(
		3, "Closed-Loop Cracking",
		"Recirculate unconverted fractions back through the cracker, sipping far less feedstock.",
		1.5, {Stockpile.ItemType.POWER_CELLS: 8}, catalyst)

	var items: Array[ResearchItem] = [column, cracker, vacuum, integrated, catalyst, closed_loop]
	return items
