extends Camera2D


@export var pan_speed: float = 600
@export var zoom_factor: float = 0.1
@export var min_zoom: float = 0.2
@export var max_zoom: float = 2

## Fraction of the viewport width covered by the StoryUI sidebar on the right.
@export var ui_width_ratio: float = 0.25
@export var cursor_label_settings: LabelSettings


var _panning := false
var _tile_centers: PackedVector2Array = []


func _ready() -> void:
	_cache_map()

	_set_zoom(min_zoom)
	position.x = get_viewport_rect().size.x * ui_width_ratio * 0.5 / zoom.x


func _process(delta: float) -> void:
	var input := Vector2(
		Input.get_axis("pan_left", "pan_right"),
		Input.get_axis("pan_up", "pan_down"),
	)
	position += input * pan_speed * delta / sqrt(zoom.x)
	_clamp_to_map()

	if _panning and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_panning = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1 + zoom_factor)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1 / (1 + zoom_factor))
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = true
	elif event.is_action_pressed("zoom_in"):
		_zoom_by(1 + zoom_factor)
	elif event.is_action_pressed("zoom_out"):
		_zoom_by(1 / (1 + zoom_factor))


func _input(event: InputEvent) -> void:
	if _panning and event is InputEventMouseMotion:
		position -= event.relative / zoom
		_clamp_to_map()


func _set_zoom(value: float) -> void:
	zoom = Vector2(value, value)
	_clamp_to_map()

	cursor_label_settings.font_size = roundi(24 / sqrt(value))
	cursor_label_settings.outline_size = roundi(12 / sqrt(value))


func _zoom_by(delta: float) -> void:
	var new_zoom := clampf(zoom.x * delta, min_zoom, max_zoom)
	_set_zoom(new_zoom)


func _cache_map() -> void:
	for tile in ZaWarudo.tiles.values():
		_tile_centers.append(tile.global_position)


## Nudges the camera to the nearest spot that still shows one whole tile inside
## the play area. Every tile is tested rather than the map's bounding box, since
## a hex has no tiles in the corners of its bounds.
func _clamp_to_map() -> void:
	if _tile_centers.is_empty():
		return

	var view := get_viewport_rect().size / zoom
	var half := ZaWarudo.tile_size * 0.5

	# Play area edges, as offsets from the camera; the sidebar eats the right.
	var left := -view.x * 0.5
	var right := view.x * (0.5 - ui_width_ratio)
	var top := -view.y * 0.5
	var bottom := view.y * 0.5

	var best := position
	var best_dist := INF
	for p in _tile_centers:
		var candidate := Vector2(
			clampf(position.x, p.x + half.x - right, p.x - half.x - left),
			clampf(position.y, p.y + half.y - bottom, p.y - half.y - top),
		)
		var dist := position.distance_squared_to(candidate)
		if dist < best_dist:
			best_dist = dist
			best = candidate
			if is_zero_approx(dist):
				break

	position = best
