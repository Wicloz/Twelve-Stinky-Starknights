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


func get_recipe() -> Recipe:
    return _recipe


# The recipe as it CURRENTLY runs, with this building type's researched upgrades
# folded in: bigger batch (production_scale), leaner input (efficiency_scale) and
# faster work (work_scale). Mirrors the maths in _try_consume / _duration.
func get_display_recipe() -> Recipe:
    var eff := Recipe.new()
    eff.display_name = _recipe.display_name
    eff.work = _recipe.work / _get_work_scale()
    var prod: int = _get_production_scale()
    var effic: float = _get_efficiency_scale()
    for item in _recipe.inputs:
        eff.inputs[item] = ceili(_recipe.inputs[item] * prod / effic)
    for item in _recipe.outputs:
        eff.outputs[item] = _recipe.outputs[item] * prod
    return eff


func _define_research() -> void:
    if not Research.can_register(self):
        return

    var items: Array[ResearchItem] = _upgrade_research()

    var automation := ResearchItem.new()
    automation.display_name = "Automation"
    automation.description = "Fully automate this factory to run without a Starknight operator."
    automation.slot = 9
    automation.cost[Stockpile.ItemType.INDUSTRIAL_CONTROLLERS] = 10
    # Capture the script in a local so the lambda does not reference `self`. A
    # lambda that touches self is bound to this building instance and goes invalid
    # if it is ever demolished, silently dropping the effect on completion.
    var script: Script = get_script()
    automation.on_complete = func() -> void:
        automated[script] = true

    items.append(automation)

    Research.register_research(self, items)


# Overridden by buildings that offer throughput upgrades (slots 1-8).
func _upgrade_research() -> Array[ResearchItem]:
    return []


# Upgrades MULTIPLY their lever, so successive tiers and parallel chains stack.
# Throughput scales with production_scale x work_scale; efficiency_scale divides
# the input each batch consumes. Base factories sit at 1 on every lever (slow and
# wasteful) -- the upgrade tree is where the power is.

# production_scale (int): bigger batches -- x`factor` output AND input per cycle.
func _output_upgrade(slot: int, name: String, description: String, factor: int, cost: Dictionary, prerequisite: ResearchItem = null) -> ResearchItem:
    var item := _new_upgrade(slot, name, description, cost, prerequisite)
    var script: Script = get_script()
    item.on_complete = func() -> void:
        production_scale[script] = int(production_scale.get(script, 1) * factor)
    return item


# work_scale (float): faster -- divides the work duration by `factor`.
func _speed_upgrade(slot: int, name: String, description: String, factor: float, cost: Dictionary, prerequisite: ResearchItem = null) -> ResearchItem:
    var item := _new_upgrade(slot, name, description, cost, prerequisite)
    var script: Script = get_script()
    item.on_complete = func() -> void:
        work_scale[script] = work_scale.get(script, 1.0) * factor
    return item


# efficiency_scale (float): leaner -- divides the input each batch consumes by `factor`.
func _efficiency_upgrade(slot: int, name: String, description: String, factor: float, cost: Dictionary, prerequisite: ResearchItem = null) -> ResearchItem:
    var item := _new_upgrade(slot, name, description, cost, prerequisite)
    var script: Script = get_script()
    item.on_complete = func() -> void:
        efficiency_scale[script] = efficiency_scale.get(script, 1.0) * factor
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
