class_name MusicPlayer
extends VBoxContainer


const MUSIC_BUS := &"Music"
const MIN_DB := -24.0
const MAX_DB := 6.0

@export var play_icon: Texture2D
@export var pause_icon: Texture2D
@export var prev_icon: Texture2D
@export var next_icon: Texture2D
@export var volume_icon: Texture2D
@export var mute_icon: Texture2D

@onready var _title: Label = $Title
@onready var _picker: OptionButton = $Picker
@onready var _prev: TextureButton = $Transport/Prev
@onready var _play_pause: TextureButton = $Transport/PlayPause
@onready var _next: TextureButton = $Transport/Next
@onready var _seek: HSlider = $Transport/Seek
@onready var _mute: TextureButton = $VolumeRow/Mute
@onready var _volume: HSlider = $VolumeRow/Volume
@onready var _player: AudioStreamPlayer = $Player

var _playlists: Dictionary[String, Array] = {}
var _names: Array[String] = []

var _current: String = ""
var _index: int = 0
var _scrubbing: bool = false
var _muted: bool = false
var _bus: int = -1

const JELLY_PLAYLIST := "Jelly Music"


func _ready() -> void:
	_define_playlists()

	_playlists[JELLY_PLAYLIST] = []
	_names.append(JELLY_PLAYLIST)

	for item in _names:
		_picker.add_item(item)

	# Assign every button icon here so none depend on being set in the scene.
	_prev.texture_normal = prev_icon
	_next.texture_normal = next_icon
	_play_pause.texture_normal = play_icon

	_picker.item_selected.connect(_on_playlist_selected)
	_prev.pressed.connect(func() -> void: _step(-1))
	_next.pressed.connect(func() -> void: _step(1))
	_play_pause.toggled.connect(_on_play_toggled)
	_player.finished.connect(func() -> void: _step(1))

	_seek.value_changed.connect(_on_seek_changed)
	_seek.drag_started.connect(_on_seek_drag_started)
	_seek.drag_ended.connect(_on_seek_drag_ended)

	# Configure the volume slider as a dB fader so its range matches the mute
	# logic below, regardless of what the scene had set.
	_bus = AudioServer.get_bus_index(MUSIC_BUS)
	_volume.min_value = MIN_DB
	_volume.max_value = MAX_DB
	_volume.step = 1.0
	_volume.value = -6.0
	_volume.value_changed.connect(_on_volume_changed)

	_mute.texture_normal = volume_icon
	_mute.toggled.connect(_on_mute_toggled)

	_apply_volume()

	if not _names.is_empty():
		_select_playlist(_names[0])


func _process(_delta: float) -> void:
	if _player.playing and not _player.stream_paused and not _scrubbing:
		_seek.set_value_no_signal(_player.get_playback_position())


func _define_playlists() -> void:
	_add("AI Generated", preload("res://assets/music/suno/Stinky Starknights.ogg"))
	_add("AI Generated", preload("res://assets/music/suno/Eating for Twelve.ogg"))
	_add("AI Generated", preload("res://assets/music/suno/Wrong Star, Baby.ogg"))
	_add("AI Generated", preload("res://assets/music/suno/Starknights build tonight.ogg"))
	_add("AI Generated", preload("res://assets/music/suno/Titanium.ogg"))


func _add(playlist: String, stream: AudioStream) -> void:
	if not _playlists.has(playlist):
		_playlists[playlist] = []
		_names.append(playlist)

	stream.loop = false
	_playlists[playlist].append(stream)


func unlock_jelly_song(stream: AudioStream) -> void:
	_add(JELLY_PLAYLIST, stream)
	_select_playlist(JELLY_PLAYLIST)

	_play_pause.set_pressed_no_signal(true)

	var index := _playlists[JELLY_PLAYLIST].size() - 1
	_play_index(index)


func _current_list() -> Array:
	return _playlists.get(_current, [])


func _on_playlist_selected(idx: int) -> void:
	_select_playlist(_names[idx])


func _select_playlist(playlist: String) -> void:
	_current = playlist
	_index = 0
	_picker.select(_names.find(playlist))
	_play_index(_index)


func _on_play_toggled(on: bool) -> void:
	if on:
		if _player.stream_paused:
			_player.stream_paused = false
		elif not _player.playing:
			_play_index(_index)
	else:
		_player.stream_paused = true

	_play_pause.texture_normal = pause_icon if on else play_icon


func _step(offset: int) -> void:
	_play_index(_index + offset)


func _play_index(index: int) -> void:
	var list := _current_list()
	if list.is_empty():
		return

	_index = wrapi(index, 0, list.size())
	_player.stream = list[_index]

	if _play_pause.button_pressed:
		_player.play()

	_seek.max_value = _player.stream.get_length()
	_seek.set_value_no_signal(0.0)
	_refresh_title()


func _on_seek_changed(value: float) -> void:
	if not _scrubbing and _player.stream != null:
		_player.seek(value)


func _on_seek_drag_started() -> void:
	_scrubbing = true


func _on_seek_drag_ended(_changed: bool) -> void:
	_scrubbing = false
	if _player.stream != null:
		_player.seek(_seek.value)


func _on_volume_changed(_db: float) -> void:
	_apply_volume()


func _on_mute_toggled(on: bool) -> void:
	_muted = on
	_mute.texture_normal = mute_icon if on else volume_icon
	_apply_volume()


func _apply_volume() -> void:
	if _muted or _volume.value <= MIN_DB:
		AudioServer.set_bus_mute(_bus, true)
	else:
		AudioServer.set_bus_mute(_bus, false)
		AudioServer.set_bus_volume_db(_bus, _volume.value)


func _refresh_title() -> void:
	var list := _current_list()
	if list.is_empty():
		_title.text = "-- empty --"
		return
	_title.text = _track_name(list[_index])


func _track_name(stream: AudioStream) -> String:
	if stream.resource_name:
		return stream.resource_name
	return stream.resource_path.get_file().get_basename()
