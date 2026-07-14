class_name Starknight
extends Node2D


enum State {IDLE, RESERVING, MOVING, WORKING}

const BASE_MOVE_SPEED: float = 220.0
const HESITATION_PER_STEP: float = 0.05
const WANDER_SPEED_FACTOR: float = 0.35
const WANDER_PAUSE_MIN: float = 0.5
const WANDER_PAUSE_MAX: float = 2.5

@export var move_speed: float = BASE_MOVE_SPEED
@export var start_tile: HexTile

var _state: State = State.IDLE
var _current_tile: HexTile
var _job: Job
var _pending_job: Job
var _hesitation_remaining: float = 0.0
var _path: Array[HexTile] = []
var _work_remaining: float = 0.0
var _wander_tile: HexTile
var _wander_pause: float = 0.0

@onready var _progress_bar: ProgressBar = $ProgressBar


func _ready() -> void:
	_current_tile = start_tile
	if start_tile:
		position = start_tile.position
	_progress_bar.hide()


func _process(delta: float) -> void:
	match _state:
		State.IDLE:
			# look for work before strolling off, or we walk away from a job
			# posted on the very tile we are standing on
			_pick_job()
			if _state == State.IDLE:
				_wander(delta)
		State.RESERVING:
			_wander(delta)
			_tick_reservation(delta)
		State.MOVING:
			_move(delta)
		State.WORKING:
			_work(delta)


## The tile we stand on, or — mid stroll — the one we are committed to walking into.
func _footing() -> HexTile:
	return _wander_tile if _wander_tile else _current_tile


## Empty means the target needs no walking, or cannot be reached at all.
func _path_to(target: HexTile) -> Array[HexTile]:
	var footing := _footing()

	var path: Array[HexTile] = []
	if target != footing:
		path = ZaWarudo.find_path(
			Vector2i(footing.q, footing.r),
			Vector2i(target.q, target.r),
		)
		if path.is_empty():
			return []

	# finish the stroll step we are halfway through before walking the rest
	if _wander_tile:
		path.push_front(_wander_tile)

	return path


func _wander(delta: float) -> void:
	if _current_tile == null:
		return

	if _wander_tile == null:
		_wander_pause -= delta
		if _wander_pause > 0.0:
			return

		var neighbors := ZaWarudo.walkable_neighbors(Vector2i(_current_tile.q, _current_tile.r))
		if neighbors.is_empty():
			return
		_wander_tile = neighbors.pick_random()
		return

	position = position.move_toward(_wander_tile.position, move_speed * WANDER_SPEED_FACTOR * delta)
	if position == _wander_tile.position:
		_current_tile = _wander_tile
		_wander_tile = null
		_wander_pause = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)


func _pick_job() -> void:
	var footing := _footing()
	if footing == null:
		return

	var nearest: Job = null
	var nearest_path: Array[HexTile] = []

	for job in JobManager.candidates():
		var path := _path_to(job.target)

		# empty for anything but the tile we stand on means unreachable
		if path.is_empty() and job.target != footing:
			continue

		if nearest == null or path.size() < nearest_path.size():
			nearest = job
			nearest_path = path

	if nearest == null:
		return

	# the further away the job is, the longer we hesitate, so nearer and
	# faster Starknights get to snatch it from under us first
	_pending_job = nearest
	_hesitation_remaining = nearest_path.size() * HESITATION_PER_STEP * BASE_MOVE_SPEED / move_speed
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

	# we may have strolled off since picking it, so re-path from where we stand now
	var path := _path_to(_pending_job.target)
	if path.is_empty() and _pending_job.target != _footing():
		JobManager.abandon(_pending_job)
		_release_reservation()
		return

	_job = _pending_job
	_pending_job = null
	_job.register_abort_handler(_abort)

	# the path owns the stroll step from here on
	_path = path
	_wander_tile = null
	_hesitation_remaining = 0.0

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
