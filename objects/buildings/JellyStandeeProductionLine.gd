class_name JellyStandeeProductionLine
extends FactoryBuilding


func get_display_name() -> String:
	return "Jelly Standee Production Line"


# Precision tooling: this line climbs the tech ladder the most evenly of any
# building, ending in integrated circuits and controllers. No capstone.
func _upgrade_research() -> Array[ResearchItem]:
	# Output chain (slot 1): mould more standees per shot.
	var molds := _output_upgrade(
		1, "Multi-Cavity Molds",
		"Cut a tool with several cavities so every shot releases a handful of Jellies.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 60})
	var carousel := _output_upgrade(
		1, "Rotary Molding Carousel",
		"A powered carousel indexes tool after tool through the press without pause.",
		2, {Stockpile.ItemType.POWER_CELLS: 30, Stockpile.ItemType.MECHANICAL_COMPONENTS: 60}, molds)

	# Speed chain (slot 2): shorten the moulding cycle.
	var cooling := _speed_upgrade(
		2, "Conformal Cooling Channels",
		"Cupronickel inserts carry coolant through the tool, freezing each shot in half the time.",
		1.5, {Stockpile.ItemType.CUPRONICKEL_INGOTS: 90})
	var servo := _speed_upgrade(
		2, "Servo-Driven Clamps",
		"Circuit-timed servo clamps snap the mould open and shut, cutting dead time to nothing.",
		1.5, {Stockpile.ItemType.ELECTRONIC_ACTUATORS: 30, Stockpile.ItemType.INTEGRATED_CIRCUITS: 45}, cooling)

	# Efficiency chain (slot 3): waste less acrylic and precious Hoshiumium.
	var regrind := _efficiency_upgrade(
		3, "Sprue Regrind",
		"Granulate the sprues and runners and feed the crumb straight back into the hopper.",
		1.5, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 50, Stockpile.ItemType.PLASTIC: 60})
	var dosing := _efficiency_upgrade(
		3, "Precision Dosing",
		"Meter every shot to the gram so almost no Hoshiumium is ever wasted.",
		1.5, {Stockpile.ItemType.ELECTRONIC_COMPONENTS: 60, Stockpile.ItemType.INDUSTRIAL_CONTROLLERS: 12}, regrind)

	var items: Array[ResearchItem] = [molds, carousel, cooling, servo, regrind, dosing]
	return items
