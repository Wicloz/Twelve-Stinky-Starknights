class_name ExtractionBuilding
extends Building


static var work_scale: Dictionary[Script, float] = {}
static var automated: Dictionary[Script, bool] = {}
static var yield_scale: Dictionary[Script, int] = {}

const BASE_WORK_SPEEDUP: float = 10.0

var _has_active_job: bool = false
var _will_harvest: Dictionary[Stockpile.ItemType, int] = {}


func _get_work_scale() -> float:
    return work_scale.get(get_script(), 1.0)


func _is_automated() -> bool:
    return automated.get(get_script(), false)


func _get_yield_scale() -> int:
    return yield_scale.get(get_script(), 1)


func _ready() -> void:
    _define_research()


func _define_research() -> void:
    if not Research.can_register(self):
        return

    var items: Array[ResearchItem] = _upgrade_research()

    var automation := ResearchItem.new()
    automation.display_name = "Automation"
    automation.description = "Fully automate this operation to run without a Starknight."
    automation.slot = 9
    automation.cost[Stockpile.ItemType.ELECTRONIC_ACTUATORS] = 10
    automation.cost[Stockpile.ItemType.POWER_CELLS] = 10
    automation.on_complete = func() -> void:
        automated[get_script()] = true

    items.append(automation)

    Research.register_research(self, items)


# Overridden by extraction sites that offer a yield upgrade (slots 1-8).
func _upgrade_research() -> Array[ResearchItem]:
    return []


# Multiplies this site's harvest amount per run (yield_scale).
func _yield_upgrade(slot: int, name: String, description: String, scale: int, cost: Dictionary, prerequisite: ResearchItem = null) -> ResearchItem:
    var item := _new_upgrade(slot, name, description, cost, prerequisite)
    var script: Script = get_script()
    item.on_complete = func() -> void:
        yield_scale[script] = scale
    return item


func _new_upgrade(slot: int, name: String, description: String, cost: Dictionary, prerequisite: ResearchItem) -> ResearchItem:
    var item := ResearchItem.new()
    item.slot = slot
    item.display_name = name
    item.description = description
    for resource in cost:
        item.cost[resource] = cost[resource]
    if prerequisite != null:
        item.prerequisites.append(prerequisite)
    return item


func _process(_delta: float) -> void:
    if _under_construction or _has_active_job:
        return

    if _is_automated():
        _automated_run()
        return

    _post_job()


func _duration() -> float:
    return tile.HARVEST_DURATION / BASE_WORK_SPEEDUP / _get_work_scale()


func _determine_harvest() -> void:
    _will_harvest[tile.deposit] = tile.HARVEST_AMOUNT * _get_yield_scale()


func _automated_run() -> void:
    _has_active_job = true
    _determine_harvest()

    await get_tree().create_timer(_duration()).timeout

    Stockpile.add_bulk(_will_harvest)
    _has_active_job = false


func _post_job() -> void:
    _has_active_job = true
    _determine_harvest()

    var job = Job.new()
    job.target = tile
    job.priority = 2
    job.duration = _duration()
    job.on_complete = _on_mine_complete
    job.on_cancel = _on_mine_aborted
    JobManager.post(job)


func _on_mine_complete() -> void:
    Stockpile.add_bulk(_will_harvest)
    _has_active_job = false


func _on_mine_aborted() -> void:
    _has_active_job = false
