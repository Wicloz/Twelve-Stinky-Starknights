@tool
class_name HexTile
extends Node2D


@export var q: int
@export var r: int

@export var walkable: bool = true

@export var terrain_texture: Texture2D:
	set(value):
		if has_node("Terrain"):
			get_node("Terrain").texture = value
	get:
		if has_node("Terrain"):
			return get_node("Terrain").texture
		return null

@export var deposit: Stockpile.ItemType = Stockpile.ItemType.NONE
@export var workable: bool = false
var harvesting: bool = false

@export var deposit_texture: Texture2D:
	set(value):
		if has_node("Deposit"):
			get_node("Deposit").texture = value
	get:
		if has_node("Deposit"):
			return get_node("Deposit").texture
		return null

const HARVEST_DURATION: float = 1.0
const HARVEST_AMOUNT: int = 1

@export var building: Building


func set_harvesting(enabled: bool) -> void:
	harvesting = enabled
	if enabled:
		_post_harvest_job()
	else:
		JobManager.cancel_jobs_on_tile(self)


func _post_harvest_job() -> void:
	var job := Job.new()
	job.priority = 1
	job.duration = HARVEST_DURATION
	job.target = self
	job.on_complete = _on_harvested
	JobManager.post(job)


func _on_harvested() -> void:
	Stockpile.add(deposit, HARVEST_AMOUNT)
	_post_harvest_job()
