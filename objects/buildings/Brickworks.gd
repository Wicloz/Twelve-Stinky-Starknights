class_name Brickworks
extends FactoryBuilding


func get_display_name() -> String:
	return "Brickworks"


# The most primitive factory: every upgrade is built out of bulk primitive stock,
# and the kiln is largely made of its OWN bricks -- so scaling it means first
# out-producing it. Three short independent chains, no capstone.
func _upgrade_research() -> Array[ResearchItem]:
	# Output chain (slot 1): bigger, hotter, ever more continuous kilns.
	var hotter := _output_upgrade(
		1, "Hotter Furnace",
		"Burn far more wood to fire a bigger charge of clay per batch.",
		2, {Stockpile.ItemType.LUMBER: 120})
	var tunnel := _output_upgrade(
		1, "Tunnel Kiln",
		"Lay up a long brick tunnel and roll the clay through it on kiln cars.",
		2, {Stockpile.ItemType.BRICKS: 240, Stockpile.ItemType.MECHANICAL_COMPONENTS: 12}, hotter)
	var roller := _output_upgrade(
		1, "Roller-Hearth Kiln",
		"A gas-fired roller hearth, lined with three times the brick, scales output higher still.",
		2, {Stockpile.ItemType.BRICKS: 480, Stockpile.ItemType.FLUID_HARDWARE: 12}, tunnel)

	# Speed chain (slot 2): drive heat through the kiln faster.
	var draft := _speed_upgrade(
		2, "Forced-Air Draft",
		"Timber bellows force air through the fire, firing each batch faster.",
		1.5, {Stockpile.ItemType.PLANKS: 30})
	var regen := _speed_upgrade(
		2, "Regenerative Preheating",
		"A firebrick checkerwork stores flue heat and preheats the next charge.",
		1.5, {Stockpile.ItemType.BRICKS: 200}, draft)

	# Efficiency chain (slot 3): spoil less clay per brick.
	var firebox := _efficiency_upgrade(
		3, "Insulated Firebox",
		"Pack the kiln walls with raw clay so heat holds even and less stock cracks.",
		1.5, {Stockpile.ItemType.CLAY: 60})
	var recovery := _efficiency_upgrade(
		3, "Kiln Heat Recovery",
		"Cupronickel ductwork reclaims waste heat to dry the green bricks with far less loss.",
		1.5, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 25, Stockpile.ItemType.CUPRONICKEL_INGOTS: 15}, firebox)

	var items: Array[ResearchItem] = [hotter, tunnel, roller, draft, regen, firebox, recovery]
	return items
