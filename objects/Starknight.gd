class_name Starknight
extends Node2D


enum State {IDLE, RESERVING, MOVING, WORKING}

const BASE_MOVE_SPEED: float = 220.0
const HESITATION_PER_STEP: float = 0.05

@export var move_speed: float = BASE_MOVE_SPEED
@export var start_tile: HexTile

var _state: State = State.IDLE
var _current_tile: HexTile
var _job: Job
var _pending_job: Job
var _hesitation_remaining: float = 0.0
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
			_pick_job()
		State.RESERVING:
			_tick_reservation(delta)
		State.MOVING:
			_move(delta)
		State.WORKING:
			_work(delta)


func _pick_job() -> void:
	if _current_tile == null:
		return

	var job := JobManager.peek_next()
	if job == null:
		return

	# already standing on it → no path to walk, claim without waiting
	if job.target == _current_tile:
		_path = []
	else:
		_path = ZaWarudo.find_path(
			Vector2i(_current_tile.q, _current_tile.r),
			Vector2i(job.target.q, job.target.r),
		)

		# empty here means unreachable (the in-place case was handled above)
		if _path.is_empty():
			return

	# the further away the job is, the longer we hesitate, so nearer and
	# faster Starknights get to snatch it from under us first
	_pending_job = job
	_hesitation_remaining = _path.size() * HESITATION_PER_STEP * BASE_MOVE_SPEED / move_speed
	_state = State.RESERVING
	_tick_reservation(0.0)


func _tick_reservation(delta: float) -> void:
	# somebody else claimed it, or it was cancelled → start over on another job
	if not JobManager.is_available(_pending_job):
		_release_reservation()
		return

	_hesitation_remaining -= delta
	if _hesitation_remaining > 0.0:
		return

	if not JobManager.claim(_pending_job):
		_release_reservation()
		return

	_job = _pending_job
	_pending_job = null
	_job.register_abort_handler(_abort)

	if _path.is_empty():
		_start_working()
		return

	_state = State.MOVING
	_set_progress(0.0)
	_progress_bar.show()


func _release_reservation() -> void:
	_pending_job = null
	_hesitation_remaining = 0.0
	_path.clear()
	_state = State.IDLE


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
