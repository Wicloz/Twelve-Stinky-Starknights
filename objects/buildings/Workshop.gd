class_name Workshop
extends Building
signal capabilities_changed


const POPUP := preload("res://objects/buildings/WorkshopPopup.tscn")

var capabilities: Array[Crafting.Capabilities] = [
	Crafting.Capabilities.FURNACE,
	Crafting.Capabilities.WORKBENCH,
]

enum Repeat {FOREVER, COUNT, UNTIL}

var order: Recipe = null
var order_repeat: Repeat = Repeat.COUNT
var order_target: int = 1

var _order_remaining: int
var _has_active_job: bool = false


func get_display_name() -> String:
	return "Workshop"


func get_popup() -> PackedScene:
	if _under_construction:
		return null
	return POPUP


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
	JobManager.cancel_jobs_on_tile(tile)


func _try_post_job() -> void:
	if _has_active_job or order == null or not _order_active() or not _can_afford(order):
		return
	_has_active_job = true

	Stockpile.remove_bulk(order.inputs)

	var job := Job.new()
	job.target = tile
	job.priority = 100
	job.duration = order.work
	job.on_complete = _on_craft_complete
	job.on_cancel = _on_craft_aborted

	JobManager.post(job)


func _on_craft_complete() -> void:
	if order_repeat == Repeat.COUNT:
		_order_remaining -= 1
	Stockpile.add_bulk(order.outputs)

	_has_active_job = false
	_try_post_job()


func _on_craft_aborted() -> void:
	Stockpile.add_bulk(order.inputs)
	_has_active_job = false


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
	Stockpile.changed.connect(_try_post_job)
