class_name Building
extends Node2D


@export var tile: HexTile

const HOLO_BLUE := preload("res://assets/shaders/holo_blue.tres")
@onready var _sprite := $Sprite2D

var _under_construction: bool = false
var _refund: Dictionary[Stockpile.ItemType, int] = {}


func get_display_name() -> String:
	return "???"


func get_popup() -> PackedScene:
	return null


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


func _construction_aborted() -> void:
	Stockpile.add_bulk(_refund)
	tile.building = null
	queue_free()
