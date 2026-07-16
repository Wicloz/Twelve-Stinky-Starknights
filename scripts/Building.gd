class_name Building
extends Node2D
signal constructed


@export var tile: HexTile

const HOLO_BLUE := preload("res://assets/shaders/holo_blue.tres")
@onready var _sprite := $Sprite2D

var _under_construction: bool = false
var _refund: Dictionary[Stockpile.ItemType, int] = {}


func get_display_name() -> String:
	return "???"


func has_popup() -> bool:
	return false


func get_popup() -> PackedScene:
	return null


func can_demolish() -> bool:
	return true


func start_construction(cost: Dictionary[Stockpile.ItemType, int]) -> void:
	_under_construction = true

	_sprite.material = HOLO_BLUE

	Stockpile.remove_bulk(cost)
	_refund = cost

	var job = Job.new()
	job.priority = 11
	job.duration = 10.0
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


func demolish() -> void:
	JobManager.cancel_jobs_on_tile(tile)
	_construction_aborted()


func is_constructed() -> bool:
	return not _under_construction
