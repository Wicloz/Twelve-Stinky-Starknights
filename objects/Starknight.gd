class_name Starknight
extends Node2D


enum State {IDLE, MOVING, WORKING}

const BASE_MOVE_SPEED: float = 220.0
const WANDER_SPEED_FACTOR: float = 0.35
const WANDER_PAUSE_MIN: float = 0.5
const WANDER_PAUSE_MAX: float = 2.5

@export var move_speed: float = BASE_MOVE_SPEED
@export var start_tile: HexTile

var _state: State = State.IDLE
var _current_tile: HexTile
var _job: Job
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
	JobManager.register(self)


func _exit_tree() -> void:
	JobManager.unregister(self)


func _process(delta: float) -> void:
	match _state:
		State.IDLE:
			_wander(delta)
		State.MOVING:
			_move(delta)
		State.WORKING:
			_work(delta)


func is_idle() -> bool:
	return _state == State.IDLE and _footing() != null


func assigned_job() -> Job:
	return _job


## Seconds of walking to reach the tile, INF when it cannot be reached at all.
func travel_time(target: HexTile) -> float:
	if _footing() == null:
		return INF

	var path := _path_to(target)
	if path.is_empty():
		# an empty path to anywhere but our own footing means unreachable
		return 0.0 if target == _footing() else INF

	var distance := 0.0
	var from := position
	for tile in path:
		distance += from.distance_to(tile.position)
		from = tile.position

	return distance / move_speed


## Take on the job. Fails if the target turned out to be unreachable after all.
func assign(job: Job) -> bool:
	var path := _path_to(job.target)
	if path.is_empty() and job.target != _footing():
		return false

	_job = job
	_job.register_abort_handler(release)

	# the path owns the stroll step we are halfway through from here on
	_path = path
	_wander_tile = null

	if _path.is_empty():
		_start_working()
		return true

	_state = State.MOVING
	_set_progress(0.0)
	_progress_bar.show()
	return true


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
		_rest()


## Hold still for a breather. Buildings only re-post their job a frame after we finish
## it, so strolling off the instant we are done would walk us away from our own post.
func _rest() -> void:
	_wander_pause = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)


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
		_rest()


func _set_progress(ratio: float) -> void:
	_progress_bar.value = clampf(ratio, 0.0, 1.0)


## Drop the job without finishing it, either because it was cancelled or because the
## JobManager handed it to a Starknight better placed to do it.
func release() -> void:
	_job = null
	_path.clear()
	_state = State.IDLE
	_progress_bar.hide()
	_rest()
