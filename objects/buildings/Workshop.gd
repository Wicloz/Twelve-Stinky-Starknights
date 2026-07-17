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

	Stockpile.remove_bulk(order.inputs)

	var job := Job.new()
	job.target = tile
	job.priority = 10
	job.duration = order.work
	job.on_complete = _on_craft_complete
	job.on_cancel = _on_craft_aborted

	_order_job = job
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
