class_name MechanicalComponentFactory
extends FactoryBuilding


func get_display_name() -> String:
	return "Mechanical Component Factory"


# The shop that caps the primitive era, so it is bought almost entirely with
# primitive bulk -- timber, brass and titanium -- and increasingly with its OWN
# components. Three chains converge on a toolroom capstone.
func _upgrade_research() -> Array[ResearchItem]:
	# Output chain (slot 1): work more benches at once.
	var shafting := _output_upgrade(
		1, "Line Shafting",
		"One engine drives every bench in the shop through belts and overhead shafts.",
		2, {Stockpile.ItemType.PLANKS: 80, Stockpile.ItemType.BRASS_INGOTS: 60})
	var transfer := _output_upgrade(
		1, "Transfer Machining",
		"Work moves itself from station to station, so the whole shop cuts as one machine.",
		2, {Stockpile.ItemType.MECHANICAL_COMPONENTS: 80, Stockpile.ItemType.FLUID_HARDWARE: 12}, shafting)

	# Speed chain (slot 2): cut metal faster.
	var tooling := _speed_upgrade(
		2, "Hardened Tooling",
		"Titanium-tipped cutters hold an edge far longer, so nobody stops to regrind.",
		1.5, {Stockpile.ItemType.RAW_TITANIUM: 60})
	var screw_machines := _speed_upgrade(
		2, "Automatic Screw Machines",
		"Cam-driven screw machines turn out finished parts without an operator touching them.",
		1.5, {Stockpile.ItemType.BRASS_INGOTS: 80, Stockpile.ItemType.MECHANICAL_COMPONENTS: 40}, tooling)

	# Efficiency chain (slot 3): waste less brass and timber per part.
	var swarf := _efficiency_upgrade(
		3, "Swarf Reclamation",
		"Sweep up the brass turnings and remelt them in a small crucible furnace.",
		1.5, {Stockpile.ItemType.CLAY: 40, Stockpile.ItemType.BRICKS: 40})
	var jigs := _efficiency_upgrade(
		3, "Jigs and Fixtures",
		"Every part is cut against a fixed jig, so scrap and rework all but disappear.",
		1.5, {Stockpile.ItemType.RAW_TITANIUM: 40, Stockpile.ItemType.PLANKS: 50}, swarf)

	# Capstone (slot 4): the shop finally builds its own machine tools.
	var toolroom := _output_upgrade(
		4, "Master Toolroom",
		"The shop starts building its own machine tools, doubling what it can turn out again.",
		2, {Stockpile.ItemType.BRASS_INGOTS: 1111, Stockpile.ItemType.MECHANICAL_COMPONENTS: 111, Stockpile.ItemType.ELECTRONIC_ACTUATORS: 11},
		[transfer, screw_machines, jigs])

	var items: Array[ResearchItem] = [shafting, transfer, tooling, screw_machines, swarf, jigs, toolroom]
	return items
