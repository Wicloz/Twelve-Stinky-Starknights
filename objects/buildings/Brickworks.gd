class_name Brickworks
extends FactoryBuilding


func get_display_name() -> String:
	return "Brickworks"


func _upgrade_research() -> Array[ResearchItem]:
	# Output chain (slot 1): bigger, hotter, ever more continuous kilns.
	var hotter := _output_upgrade(
		1, "Hotter Furnace",
		"Stoke the kiln with more lumber to fire more clay per batch.",
		2, {Stockpile.ItemType.LUMBER: 15})
	var tunnel := _output_upgrade(
		1, "Tunnel Kiln",
		"Conveyor cars roll bricks through a continuous kiln, baking far larger batches.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 15}, hotter)
	var roller := _output_upgrade(
		1, "Roller-Hearth Kiln",
		"A gas-fired roller-hearth kiln scales brick output higher still.",
		2, {Stockpile.ItemType.FLUID_HARDWARE: 10}, tunnel)

	# Speed chain (slot 2): drive heat through the kiln faster.
	var draft := _speed_upgrade(
		2, "Forced-Air Draft",
		"Blowers force hot air through the kiln, firing each batch faster.",
		1.5, {Stockpile.ItemType.PLANKS: 20})
	var regen := _speed_upgrade(
		2, "Regenerative Preheating",
		"Recovered flue heat preheats the next charge, firing faster still.",
		1.5, {Stockpile.ItemType.FLUID_HARDWARE: 10}, draft)

	# Efficiency chain (slot 3): spoil less clay per brick.
	var firebox := _efficiency_upgrade(
		3, "Insulated Firebox",
		"Refractory insulation holds heat evenly, cracking and spoiling less clay.",
		1.5, {Stockpile.ItemType.BRICKS: 20})
	var recovery := _efficiency_upgrade(
		3, "Kiln Heat Recovery",
		"Reclaimed waste heat dries and sets the clay with far less loss.",
		1.5, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 15}, firebox)

	var items: Array[ResearchItem] = [hotter, tunnel, roller, draft, regen, firebox, recovery]
	return items
