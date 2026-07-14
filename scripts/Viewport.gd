extends Camera2D


@export var pan_speed: float = 600
@export var zoom_factor: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2

var _panning := false


func _ready() -> void:
	zoom = Vector2(min_zoom, min_zoom)


func _process(delta: float) -> void:
	var input := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"),
	)
	position += input * pan_speed * delta / sqrt(zoom.x)

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
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
			_zoom_by(1 + zoom_factor)
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			_zoom_by(1 / (1 + zoom_factor))


func _input(event: InputEvent) -> void:
	if _panning and event is InputEventMouseMotion:
		position -= event.relative / zoom


func _zoom_by(delta: float) -> void:
	var new_zoom := clampf(zoom.x * delta, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)
