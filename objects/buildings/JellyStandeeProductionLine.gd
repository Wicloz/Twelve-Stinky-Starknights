class_name JellyStandeeProductionLine
extends FactoryBuilding


func get_display_name() -> String:
	return "Jelly Standee Production Line"


func _upgrade_research() -> Array[ResearchItem]:
	# Output chain (slot 1): mould more standees per shot.
	var molds := _output_upgrade(
		1, "Multi-Cavity Molds",
		"Injection-mould several standees per shot.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 15})
	var carousel := _output_upgrade(
		1, "Rotary Molding Carousel",
		"A rotary mould carousel cycles far more standees at once.",
		2, {Stockpile.ItemType.POWER_CELLS: 8}, molds)

	# Speed chain (slot 2): shorten the moulding cycle.
	var cooling := _speed_upgrade(
		2, "Conformal Cooling Channels",
		"Conformal cooling channels solidify each shot faster.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 15})
	var servo := _speed_upgrade(
		2, "Servo-Driven Clamps",
		"Servo clamps open and close the mould faster, shortening every cycle further.",
		1.5, {Stockpile.ItemType.ELECTRONIC_ACTUATORS: 8}, cooling)

	# Efficiency chain (slot 3): waste less acrylic and precious Hoshiumium.
	var regrind := _efficiency_upgrade(
		3, "Sprue Regrind",
		"Grind and remelt the sprues and runners, consuming less acrylic per standee.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 15})
	var dosing := _efficiency_upgrade(
		3, "Precision Dosing",
		"Meter each shot precisely so far less acrylic and Hoshiumium is wasted.",
		1.5, {Stockpile.ItemType.POWER_CELLS: 8}, regrind)

	var items: Array[ResearchItem] = [molds, carousel, cooling, servo, regrind, dosing]
	return items
