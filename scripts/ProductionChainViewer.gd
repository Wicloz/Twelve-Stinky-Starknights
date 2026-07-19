extends Control
## Full-screen overlay (excluding the story sidebar) that shows the production
## chain diagram. The player can pan it by dragging and zoom with the wheel, and
## dismiss it with ESC or the close button.


@export var zoom_step: float = 0.1
@export var help_button: TextureButton

@onready var _clip: Control = $ImageClip
@onready var _image: TextureRect = $ImageClip/Image
@onready var _close_button: TextureButton = $CloseButton

var _zoom: float = 1.0
var _fit_zoom: float = 1.0
var _max_zoom: float = 1.0
var _center: Vector2 = Vector2.ZERO
var _dragging: bool = false


func _ready() -> void:
	hide()
	_close_button.pressed.connect(close)
	if help_button:
		help_button.pressed.connect(open)


func open() -> void:
	show()
	_reset_view()


func close() -> void:
	_dragging = false
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		_reset_view()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("zoom_in"):
		_zoom_at(1 + zoom_step, _clip.size * 0.5)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("zoom_out"):
		_zoom_at(1 / (1 + zoom_step), _clip.size * 0.5)
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(1 + zoom_step, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(1 / (1 + zoom_step), event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_center += event.relative
		_clamp_center()
		_apply_transform()
		accept_event()


## Recomputes the fit-to-view zoom and centres the diagram.
func _reset_view() -> void:
	var tex_size := _image.texture.get_size()
	_image.size = tex_size
	_image.pivot_offset = tex_size * 0.5

	var area := _clip.size
	_fit_zoom = minf(area.x / tex_size.x, area.y / tex_size.y)
	_max_zoom = maxf(_fit_zoom * 8.0, 4.0)
	_zoom = _fit_zoom
	_center = area * 0.5
	_apply_transform()


func _zoom_at(factor: float, pivot: Vector2) -> void:
	var new_zoom := clampf(_zoom * factor, _fit_zoom, _max_zoom)
	factor = new_zoom / _zoom
	_center = pivot + (_center - pivot) * factor
	_zoom = new_zoom
	_clamp_center()
	_apply_transform()


func _apply_transform() -> void:
	_image.scale = Vector2(_zoom, _zoom)
	_image.position = _center - _image.size * 0.5


## Keeps the diagram from being dragged out of the visible area: it stays centred
## on any axis where it is smaller than the view, and hugs the edges otherwise.
func _clamp_center() -> void:
	var half := _image.size * _zoom * 0.5
	var area := _clip.size
	if half.x * 2.0 <= area.x:
		_center.x = area.x * 0.5
	else:
		_center.x = clampf(_center.x, area.x - half.x, half.x)
	if half.y * 2.0 <= area.y:
		_center.y = area.y * 0.5
	else:
		_center.y = clampf(_center.y, area.y - half.y, half.y)
