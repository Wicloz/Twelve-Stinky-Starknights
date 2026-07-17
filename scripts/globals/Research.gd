extends Node
signal changed


var _items: Array[ResearchItem] = []


func _ready() -> void:
	_define_research()
	_refresh_states()


func available_for(building: Building) -> Array[ResearchItem]:
	var type: Script = building.get_script()
	var by_slot: Dictionary[int, ResearchItem] = {}

	for item in _items:
		if item.research_at != type:
			continue
		if item.state == ResearchItem.State.COMPLETED:
			continue
		if item.slot in by_slot:
			continue

		by_slot[item.slot] = item

	var result: Array[ResearchItem] = by_slot.values()
	return result


func slot_count_for(building: Building) -> int:
	var type: Script = building.get_script()
	var count := 0

	for item in _items:
		if item.research_at == type:
			count = maxi(count, item.slot + 1)

	return count


func can_research(item: ResearchItem) -> bool:
	if item.state != ResearchItem.State.AVAILABLE:
		return false

	for resource in item.cost:
		if Stockpile.get_amount(resource) < item.cost[resource]:
			return false

	return true


func start_research(item: ResearchItem, building: Building) -> void:
	if not can_research(item):
		return

	Stockpile.remove_bulk(item.cost)
	item.state = ResearchItem.State.RESEARCHING

	var job := Job.new()
	job.target = building.tile
	job.priority = 11
	job.duration = item.work
	job.on_complete = _on_research_completed.bind(item)
	job.on_cancel = _on_research_cancelled.bind(item)
	JobManager.post(job)

	changed.emit()


func _on_research_completed(item: ResearchItem) -> void:
	item.state = ResearchItem.State.COMPLETED

	if item.on_complete.is_valid():
		item.on_complete.call()

	_refresh_states()
	changed.emit()


func _on_research_cancelled(item: ResearchItem) -> void:
	Stockpile.add_bulk(item.cost)
	item.state = ResearchItem.State.AVAILABLE
	changed.emit()


func _refresh_states() -> void:
	for item in _items:
		if item.state == ResearchItem.State.COMPLETED:
			continue
		if item.state == ResearchItem.State.RESEARCHING:
			continue

		if _prerequisites_met(item):
			item.state = ResearchItem.State.AVAILABLE
		else:
			item.state = ResearchItem.State.LOCKED


func _prerequisites_met(item: ResearchItem) -> bool:
	for prerequisite in item.prerequisites:
		if prerequisite.state != ResearchItem.State.COMPLETED:
			return false
	return true


static func _scale_float(modifiers: Dictionary, type: Script, factor: float) -> void:
	modifiers[type] = factor


static func _scale_int(modifiers: Dictionary, type: Script, factor: int) -> void:
	modifiers[type] = factor


static func _enable(flags: Dictionary, type: Script) -> void:
	flags[type] = true


func _define_research() -> void:
	var ergonomic_tools := ResearchItem.new()
	_items.append(ergonomic_tools)

	ergonomic_tools.display_name = "Ergonomic Tools"
	ergonomic_tools.description = "Starknights move 25% faster."
	ergonomic_tools.research_at = Workshop
	ergonomic_tools.slot = 0
	ergonomic_tools.cost[Stockpile.ItemType.PLANKS] = 50
	ergonomic_tools.cost[Stockpile.ItemType.BRASS_INGOTS] = 10
	ergonomic_tools.on_complete = func() -> void:
		Starknight.speed_scale = 1.25

	var powered_exoskeletons := ResearchItem.new()
	_items.append(powered_exoskeletons)

	powered_exoskeletons.display_name = "Powered Exoskeletons"
	powered_exoskeletons.description = "Starknights move a further 25% faster."
	powered_exoskeletons.research_at = Workshop
	powered_exoskeletons.slot = 0
	powered_exoskeletons.prerequisites.append(ergonomic_tools)
	powered_exoskeletons.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 25
	powered_exoskeletons.cost[Stockpile.ItemType.ELECTRUM_WIRE] = 25
	powered_exoskeletons.on_complete = func() -> void:
		Starknight.speed_scale = 1.50
