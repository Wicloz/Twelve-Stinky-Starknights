class_name Starknight
extends Node2D


enum State {IDLE, MOVING, WORKING}

@export var move_speed: float = 220.0
@export var start_tile: HexTile

var _state := State.IDLE
var _current_tile: HexTile
var _job: Job
var _path: Array[HexTile] = []
var _work_remaining: float = 0.0

@onready var _progress_bar: ProgressBar = $ProgressBar


func _ready() -> void:
	_current_tile = start_tile
	if start_tile:
		position = start_tile.position
	_progress_bar.hide()


func _process(delta: float) -> void:
	match _state:
		State.IDLE:
			_try_claim()
		State.MOVING:
			_move(delta)
		State.WORKING:
			_work(delta)


func _try_claim() -> void:
	if _current_tile == null:
		return

	var job := JobManager.claim_next()
	if job == null:
		return

	_job = job
	job.register_abort_handler(_abort)

	# already standing on it → work in place
	if job.target == _current_tile:
		_start_working()
		return

	_path = ZaWarudo.find_path(
		Vector2i(_current_tile.q, _current_tile.r),
		Vector2i(job.target.q, job.target.r),
	)

	# empty here means unreachable (the in-place case was handled above)
	if _path.is_empty():
		_job = null
		JobManager.abandon(job)
		return

	_state = State.MOVING
	_set_progress(0.0)
	_progress_bar.show()


func _move(delta: float) -> void:
	var next_tile := _path[0]
	position = position.move_toward(next_tile.position, move_speed * delta)

	if position == next_tile.position:
		_current_tile = next_tile
		_path.remove_at(0)
		if _path.is_empty():
			_start_working()


func _start_working() -> void:
	_work_remaining = _job.duration
	_state = State.WORKING
	_set_progress(0.0)
	_progress_bar.show()


func _work(delta: float) -> void:
	_work_remaining -= delta
	_set_progress(1.0 - _work_remaining / _job.duration)

	if _work_remaining <= 0.0:
		_state = State.IDLE
		_progress_bar.hide()
		JobManager.complete(_job)
		_job = null


func _set_progress(ratio: float) -> void:
	_progress_bar.value = clampf(ratio, 0.0, 1.0)


func _abort() -> void:
	_job = null
	_path.clear()
	_state = State.IDLE
	_progress_bar.hide()
