class_name FactoryBuilding
extends Building


@export var recipe: Crafting.RecipeType
const BASE_WORK_SPEEDUP: float = 10.0

static var work_scale: Dictionary[Script, float] = {}
static var automated: Dictionary[Script, bool] = {}
static var efficiency_scale: Dictionary[Script, float] = {}
static var production_scale: Dictionary[Script, int] = {}

var _recipe: Recipe
var _has_active_job: bool = false
var _has_consumed: Dictionary[Stockpile.ItemType, int] = {}
var _will_produce: Dictionary[Stockpile.ItemType, int] = {}


func _ready() -> void:
    _recipe = Crafting.get_recipe(recipe)
    _define_research()


func _define_research() -> void:
    if not Research.can_register(self):
        return

    var items: Array[ResearchItem] = _upgrade_research()

    var automation := ResearchItem.new()
    automation.display_name = "Automation"
    automation.description = "Fully automate this factory to run without a Starknight operator."
    automation.slot = 9
    automation.cost[Stockpile.ItemType.INDUSTRIAL_CONTROLLERS] = 10
    automation.on_complete = func() -> void:
        automated[get_script()] = true

    items.append(automation)

    Research.register_research(self, items)


# Overridden by buildings that offer throughput upgrades (slots 1-8).
func _upgrade_research() -> Array[ResearchItem]:
    return []


# Multiplies this factory's batch size: more output (and input) per work cycle.
func _output_upgrade(slot: int, name: String, description: String, scale: int, cost: Dictionary, prerequisite: ResearchItem = null) -> ResearchItem:
    var item := _new_upgrade(slot, name, description, cost, prerequisite)
    var script: Script = get_script()
    item.on_complete = func() -> void:
        production_scale[script] = scale
    return item


# Divides this factory's work duration: the same batch is produced faster.
func _speed_upgrade(slot: int, name: String, description: String, scale: float, cost: Dictionary, prerequisite: ResearchItem = null) -> ResearchItem:
    var item := _new_upgrade(slot, name, description, cost, prerequisite)
    var script: Script = get_script()
    item.on_complete = func() -> void:
        work_scale[script] = scale
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


func _get_work_scale() -> float:
    return work_scale.get(get_script(), 1.0)


func _is_automated() -> bool:
    return automated.get(get_script(), false)


func _get_efficiency_scale() -> float:
    return efficiency_scale.get(get_script(), 1.0)


func _get_production_scale() -> int:
    return production_scale.get(get_script(), 1)


func _process(_delta: float) -> void:
    if _under_construction or _has_active_job:
        return

    if _is_automated():
        _try_automated_run()
        return

    _try_post_job()


func _duration() -> float:
    return _recipe.work / BASE_WORK_SPEEDUP / _get_work_scale()


func _try_consume() -> bool:
    var inputs: Dictionary[Stockpile.ItemType, int] = {}

    for item in _recipe.inputs:
        inputs[item] = ceili(_recipe.inputs[item] * _get_production_scale() / _get_efficiency_scale())
        if Stockpile.get_amount(item) < inputs[item]:
            return false

    Stockpile.remove_bulk(inputs)
    _has_consumed = inputs

    _will_produce.clear()
    for item in _recipe.outputs:
        _will_produce[item] = _recipe.outputs[item] * _get_production_scale()

    return true


func _try_automated_run() -> void:
    if not _try_consume():
        return

    _has_active_job = true

    await get_tree().create_timer(_duration()).timeout

    Stockpile.add_bulk(_will_produce)
    _has_active_job = false


func _try_post_job() -> void:
    if not _try_consume():
        return

    _has_active_job = true

    var job = Job.new()
    job.target = tile
    job.priority = 2
    job.duration = _duration()
    job.on_complete = _on_craft_complete
    job.on_cancel = _on_craft_aborted
    JobManager.post(job)


func _on_craft_complete() -> void:
    Stockpile.add_bulk(_will_produce)
    _has_active_job = false


func _on_craft_aborted() -> void:
    Stockpile.add_bulk(_has_consumed)
    _has_active_job = false
