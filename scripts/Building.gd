class_name Building
extends Node2D
signal constructed


@export var tile: HexTile:
	set(value):
		tile = value
		_fit_sprite_to_tile()

const HOLO_BLUE := preload("res://assets/shaders/holo_blue.tres")
@export var SCALE_FACTOR: float = 0.9

var _sprite_holder: Sprite2D = null
var _sprite: Sprite2D:
	get:
		if _sprite_holder == null:
			_sprite_holder = $Sprite2D
		return _sprite_holder

var _under_construction: bool = false
var _refund: Dictionary[Stockpile.ItemType, int] = {}


func multiply_by_this() -> float:
	return SCALE_FACTOR / _sprite.texture.get_width()


func _fit_sprite_to_tile() -> void:
	if tile == null:
		return
	_sprite.scale = Vector2.ONE * tile.terrain_texture_width * multiply_by_this()


func get_display_name() -> String:
	return "???"


func get_recipe() -> Recipe:
	return null


func has_popup() -> bool:
	return false


func get_popup() -> PackedScene:
	return null


func can_demolish() -> bool:
	return true


func start_construction(cost: Dictionary[Stockpile.ItemType, int], work: float) -> void:
	_under_construction = true

	_sprite.material = HOLO_BLUE

	Stockpile.remove_bulk(cost)
	_refund = cost

	var job = Job.new()
	job.priority = 12
	job.duration = work
	job.target = tile
	job.on_complete = _construction_complete
	job.on_cancel = _construction_aborted
	JobManager.post(job)


func _construction_complete() -> void:
	_sprite.material = null
	_under_construction = false
	constructed.emit()
	Catalog.building_finished_construction(get_script())


func _construction_aborted() -> void:
	Stockpile.add_bulk(_refund)
	tile.building = null
	queue_free()


func abort() -> void:
	JobManager.cancel_jobs_on_tile(tile)


func demolish() -> void:
	JobManager.cancel_jobs_on_tile(tile)
	_construction_aborted()
	Catalog.building_destroyed(get_script())


func is_constructed() -> bool:
	return not _under_construction
