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


func try_research(item: ResearchItem, building: Building):
	if not building.is_constructed():
		return "This building is still under construction."

	match item.state:
		ResearchItem.State.COMPLETED:
			return "This upgrade has already been researched."
		ResearchItem.State.RESEARCHING:
			return "This upgrade is already being researched."
		ResearchItem.State.LOCKED:
			var locked := "Missing prerequisites for this upgrade:"
			for prerequisite in item.prerequisites:
				if prerequisite.state != ResearchItem.State.COMPLETED:
					locked += "\n" + "  - %s" % prerequisite.display_name
			return locked

	var missing: Dictionary[Stockpile.ItemType, int] = {}

	for resource in item.cost:
		var missing_amount := item.cost[resource] - Stockpile.get_amount(resource)
		if missing_amount > 0:
			missing[resource] = missing_amount

	if missing.size() > 0:
		var error := "Not enough resources to research this upgrade:"
		for resource in missing:
			error += "\n" + "  - missing %d %s" % [missing[resource], Stockpile.get_display_name(resource)]
		return error

	start_research(item, building)

	return false


func start_research(item: ResearchItem, building: Building) -> void:
	if not can_research(item):
		return

	Stockpile.remove_bulk(item.cost)
	item.state = ResearchItem.State.RESEARCHING

	ActivityLog.record_research(item, building)

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
