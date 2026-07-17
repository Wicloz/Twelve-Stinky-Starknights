extends Node
signal changed


var _items: Array[ResearchItem] = []
var _registered: Array[Script] = []


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


func register_research(building: Building, research: Array[ResearchItem]) -> void:
	var script: Script = building.get_script()

	for item in research:
		item.research_at = script
		_items.append(item)

	_refresh_states()
	_registered.append(script)


func can_register(building: Building) -> bool:
	var script: Script = building.get_script()
	return not script in _registered
