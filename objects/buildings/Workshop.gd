class_name Workshop
extends Building


const POPUP := preload("res://objects/buildings/WorkshopPopup.tscn")

static var capabilities: Array[Crafting.Capabilities] = [
	Crafting.Capabilities.FURNACE,
	Crafting.Capabilities.WORKBENCH,
]

enum Repeat {FOREVER, COUNT, UNTIL}

var order: Recipe = null
var order_repeat: Repeat = Repeat.COUNT
var order_target: int = 1

var _order_remaining: int
var _order_job: Job = null


static func has_capability(capability: Crafting.Capabilities) -> bool:
	return capability in capabilities


func _define_research() -> void:
	if not Research.can_register(self):
		return
	var research: Array[ResearchItem] = []

	var workbench := ResearchItem.new()
	research.append(workbench)

	workbench.display_name = "Workbench"
	workbench.description = "A table and a variety of hand tools. Great for shaping wood and soft metals, and not much else."
	workbench.slot = 1
	workbench.state = ResearchItem.State.COMPLETED

	var power_tools := ResearchItem.new()
	research.append(power_tools)

	power_tools.display_name = "Power Tools"
	power_tools.description = "A set of electric tools for more precise work and tougher materials."
	power_tools.slot = 1
	power_tools.prerequisites.append(workbench)
	power_tools.cost[Stockpile.ItemType.BRASS_INGOTS] = 80
	power_tools.cost[Stockpile.ItemType.ELECTRONIC_ACTUATORS] = 4
	power_tools.on_complete = func() -> void:
		Workshop.capabilities.append(Crafting.Capabilities.POWER_TOOLS)

	var lathe := ResearchItem.new()
	research.append(lathe)

	lathe.display_name = "Lathe"
	lathe.description = "Precision metal turning for creating intricate parts."
	lathe.slot = 2
	lathe.prerequisites.append(workbench)
	lathe.cost[Stockpile.ItemType.BRASS_INGOTS] = 80
	lathe.cost[Stockpile.ItemType.ELECTRONIC_ACTUATORS] = 4
	lathe.cost[Stockpile.ItemType.RAW_TITANIUM] = 40
	lathe.on_complete = func() -> void:
		Workshop.capabilities.append(Crafting.Capabilities.LATHE)

	var cnc_mill := ResearchItem.new()
	research.append(cnc_mill)

	cnc_mill.display_name = "CNC Mill"
	cnc_mill.description = "Computer controlled milling machine for precision metalwork."
	cnc_mill.slot = 3
	cnc_mill.prerequisites.append(workbench)
	cnc_mill.cost[Stockpile.ItemType.BRASS_INGOTS] = 80
	cnc_mill.cost[Stockpile.ItemType.ELECTRONIC_ACTUATORS] = 4
	cnc_mill.cost[Stockpile.ItemType.RAW_TITANIUM] = 40
	cnc_mill.on_complete = func() -> void:
		Workshop.capabilities.append(Crafting.Capabilities.CNC_MILL)

	var assembly_station := ResearchItem.new()
	research.append(assembly_station)

	assembly_station.display_name = "Assembly Station"
	assembly_station.description = "Additional space and tools for assembling complex machinery."
	assembly_station.slot = 1
	assembly_station.prerequisites.append(lathe)
	assembly_station.prerequisites.append(cnc_mill)
	assembly_station.prerequisites.append(power_tools)
	assembly_station.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 100
	assembly_station.cost[Stockpile.ItemType.ELECTRONIC_COMPONENTS] = 20
	assembly_station.cost[Stockpile.ItemType.INTEGRATED_CIRCUITS] = 20
	assembly_station.on_complete = func() -> void:
		Workshop.capabilities.append(Crafting.Capabilities.ASSEMBLY_STATION)

	var overhead_crane := ResearchItem.new()
	research.append(overhead_crane)

	overhead_crane.display_name = "Overhead Crane"
	overhead_crane.description = "A large crane integrated into the roof structure, required to move heavy objects around."
	overhead_crane.slot = 6
	overhead_crane.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 100
	overhead_crane.cost[Stockpile.ItemType.RAW_TITANIUM] = 100
	overhead_crane.cost[Stockpile.ItemType.FLUID_HARDWARE] = 20
	overhead_crane.cost[Stockpile.ItemType.ELECTRONIC_ACTUATORS] = 20
	overhead_crane.on_complete = func() -> void:
		Workshop.capabilities.append(Crafting.Capabilities.OVERHEAD_CRANE)

	var furnace := ResearchItem.new()
	research.append(furnace)

	furnace.display_name = "Furnace"
	furnace.description = "Very hot. Melts metals and bakes bricks."
	furnace.slot = 4
	furnace.state = ResearchItem.State.COMPLETED

	var refinery := ResearchItem.new()
	research.append(refinery)

	refinery.display_name = "Refinery"
	refinery.description = "Distills petrochemicals and distills mineral water."
	refinery.slot = 4
	refinery.prerequisites.append(furnace)
	refinery.cost[Stockpile.ItemType.BRICKS] = 400
	refinery.cost[Stockpile.ItemType.RAW_TITANIUM] = 400
	refinery.cost[Stockpile.ItemType.FLUID_HARDWARE] = 10
	refinery.on_complete = func() -> void:
		Workshop.capabilities.append(Crafting.Capabilities.REFINERY)

	var injection_molding := ResearchItem.new()
	research.append(injection_molding)

	injection_molding.display_name = "Injection Molding"
	injection_molding.description = "For molding plastics into any shape your heart desires."
	injection_molding.slot = 5
	injection_molding.prerequisites.append(workbench)
	injection_molding.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 40
	injection_molding.cost[Stockpile.ItemType.FLUID_HARDWARE] = 2
	injection_molding.on_complete = func() -> void:
		Workshop.capabilities.append(Crafting.Capabilities.INJECTION_MOLDING)

	var wire_mill := ResearchItem.new()
	research.append(wire_mill)

	wire_mill.display_name = "Wire Mill"
	wire_mill.description = "Turns metals into spools of wire."
	wire_mill.slot = 7
	wire_mill.prerequisites.append(workbench)
	wire_mill.cost[Stockpile.ItemType.RAW_TITANIUM] = 80
	wire_mill.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 40
	wire_mill.on_complete = func() -> void:
		Workshop.capabilities.append(Crafting.Capabilities.WIRE_MILL)

	var soldering_station := ResearchItem.new()
	research.append(soldering_station)

	soldering_station.display_name = "Soldering Station"
	soldering_station.description = "Soldering iron and fume extractor. For bonding wires, components, and PCBs."
	soldering_station.slot = 8
	soldering_station.prerequisites.append(workbench)
	soldering_station.cost[Stockpile.ItemType.ELECTRUM_WIRE] = 400
	soldering_station.cost[Stockpile.ItemType.POWER_CELLS] = 20
	soldering_station.on_complete = func() -> void:
		Workshop.capabilities.append(Crafting.Capabilities.SOLDERING_STATION)

	var cleanroom := ResearchItem.new()
	research.append(cleanroom)

	cleanroom.display_name = "Cleanroom"
	cleanroom.description = "A sealed room with filtered air and strict contamination controls. Required for manufacturing sensitive electronics."
	cleanroom.slot = 9
	cleanroom.prerequisites.append(soldering_station)
	cleanroom.prerequisites.append(wire_mill)
	cleanroom.cost[Stockpile.ItemType.BRICKS] = 400
	cleanroom.cost[Stockpile.ItemType.PLASTIC] = 400
	cleanroom.cost[Stockpile.ItemType.FLUID_HARDWARE] = 20
	cleanroom.on_complete = func() -> void:
		Workshop.capabilities.append(Crafting.Capabilities.CLEANROOM)

	var lithography := ResearchItem.new()
	research.append(lithography)

	lithography.display_name = "Lithography System"
	lithography.description = "Creates intricate patterns on semiconductor wafers using UV light."
	lithography.slot = 9
	lithography.prerequisites.append(cleanroom)
	lithography.cost[Stockpile.ItemType.ELECTRONIC_COMPONENTS] = 200
	lithography.cost[Stockpile.ItemType.SAND] = 200
	lithography.cost[Stockpile.ItemType.RAW_TITANIUM] = 200
	lithography.on_complete = func() -> void:
		Workshop.capabilities.append(Crafting.Capabilities.LITHOGRAPHY)

	Research.register_research(self, research)


func get_display_name() -> String:
	return "Workshop"


func has_popup() -> bool:
	return not _under_construction


func get_popup() -> PackedScene:
	return POPUP


func can_demolish() -> bool:
	return false


func apply_order(recipe: Recipe, repeat: Repeat, target: int) -> void:
	_cancel_current_job()

	order = recipe
	order_repeat = repeat
	order_target = target

	if order_repeat == Repeat.COUNT:
		_order_remaining = order_target

	_try_post_job()


func clear_order() -> void:
	_cancel_current_job()

	order = null
	order_repeat = Repeat.COUNT
	order_target = 1


func _cancel_current_job() -> void:
	if _order_job == null:
		return

	JobManager.cancel(_order_job)
	_order_job = null


func _try_post_job() -> void:
	if _order_job != null or order == null or not _order_active() or not _can_afford(order):
		return

	var job := Job.new()
	job.target = tile
	job.priority = 10
	job.duration = order.work
	job.on_complete = _on_craft_complete
	job.on_cancel = _on_craft_aborted

	_order_job = job

	Stockpile.remove_bulk(order.inputs)
	JobManager.post(job)


func _on_craft_complete() -> void:
	if order_repeat == Repeat.COUNT:
		_order_remaining -= 1
	Stockpile.add_bulk(order.outputs)

	_order_job = null
	_try_post_job()


func _on_craft_aborted() -> void:
	Stockpile.add_bulk(order.inputs)
	_order_job = null


func _can_afford(recipe: Recipe) -> bool:
	for item in recipe.inputs:
		if Stockpile.get_amount(item) < recipe.inputs[item]:
			return false
	return true


func _order_active() -> bool:
	match order_repeat:
		Repeat.FOREVER:
			return true
		Repeat.COUNT:
			return _order_remaining > 0
		Repeat.UNTIL:
			for item in order.outputs:
				if Stockpile.get_amount(item) < order_target:
					return true
			return false
	return false


func _ready() -> void:
	_define_research()
	Stockpile.changed.connect(_try_post_job)
	Stockpile.challenge_updated.connect(_on_challenge_updated)


func _on_challenge_updated() -> void:
	if order == null:
		return

	for item in order.outputs:
		if Stockpile.is_unavailable_story_item(item):
			clear_order()
			return

	for item in order.inputs:
		if Stockpile.is_unavailable_story_item(item):
			clear_order()
			return
