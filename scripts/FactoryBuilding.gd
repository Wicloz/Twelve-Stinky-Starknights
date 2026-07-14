class_name FactoryBuilding
extends Building


@export var recipe: Crafting.RecipeType

var _recipe: Recipe
var _has_active_job: bool = false


func _ready() -> void:
    _recipe = Crafting.get_recipe(recipe)


func _process(delta: float) -> void:
    if _under_construction or _has_active_job:
        return

    _try_post_job()


func _try_post_job() -> void:
    for item in _recipe.inputs:
        if Stockpile.get_amount(item) < _recipe.inputs[item]:
            return

    _has_active_job = true
    Stockpile.remove_bulk(_recipe.inputs)

    var job = Job.new()
    job.target = tile
    job.priority = 2
    job.duration = _recipe.work / 10
    job.on_complete = _on_craft_complete
    job.on_cancel = _on_craft_aborted
    JobManager.post(job)


func _on_craft_complete() -> void:
    Stockpile.add_bulk(_recipe.outputs)
    _has_active_job = false
    _try_post_job()


func _on_craft_aborted() -> void:
    Stockpile.add_bulk(_recipe.inputs)
    _has_active_job = false
