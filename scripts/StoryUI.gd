extends PanelContainer


@onready var video := $VBox/CutsceneViewer/VideoAspect/VideoDisplay
@onready var image := $VBox/CutsceneViewer/ImageAspect/ImageDisplay
@onready var narration := $VBox/Narration
@onready var video_aspect := $VBox/CutsceneViewer/VideoAspect
@onready var image_aspect := $VBox/CutsceneViewer/ImageAspect
@onready var letterbox := $VBox/CutsceneViewer/Letterbox
@onready var music_player: MusicPlayer = $VBox/MusicPlayer

var _reveal: Tween


func _ready() -> void:
	Story.cutscene_started.connect(_on_cutscene_started)
	Story.play_next()


func _on_cutscene_started(cutscene: Cutscene) -> void:
	if _reveal and _reveal.is_running():
		_reveal.kill()
		narration.visible_characters = -1
		image.visible = false
		video.visible = false
		letterbox.color = Color(0, 0, 0, 1)

	if cutscene.still != null:
		image.texture = cutscene.still
		image.visible = true
		_fit_media(image_aspect, cutscene.still.get_size())

	if cutscene.video != null:
		video.stream = cutscene.video
		video.visible = true
		video.play()
		# The video texture isn't sized until the first frame is decoded.
		await get_tree().process_frame
		_fit_media(video_aspect, video.get_video_texture().get_size())

	if cutscene.song != null:
		music_player.unlock_jelly_song(cutscene.song)

	letterbox.color = Color(1, 1, 1, 1)
	_reveal_text(cutscene.text, cutscene.typing_speed, cutscene.min_duration)


func _fit_media(aspect: AspectRatioContainer, px: Vector2) -> void:
	if px.y > 0.0:
		aspect.ratio = px.x / px.y


func _reveal_text(bbcode: String, typing_speed: float, min_duration: float) -> void:
	var from: int = narration.get_total_character_count()
	narration.append_text(bbcode + "\n\n")
	var to: int = narration.get_total_character_count() - 2

	var new_chars := to - from
	var type_time := 0.0
	if typing_speed > 0.0 and new_chars > 0:
		type_time = new_chars / typing_speed

	# End no sooner than min_duration, even when the text types out faster.
	var total_time: float = max(type_time, min_duration)
	var typing := new_chars > 0 and type_time > 0.0

	narration.visible_characters = from if typing else -1

	if total_time <= 0.0:
		narration.visible_characters = -1
		_on_text_revealed()
		return

	_reveal = create_tween()
	if typing:
		_reveal.tween_property(narration, "visible_characters", to, type_time)
	if total_time > type_time:
		_reveal.tween_interval(total_time - type_time)
	_reveal.finished.connect(func() -> void:
		narration.visible_characters = -1
		_on_text_revealed()
	)


func _on_text_revealed() -> void:
	image.visible = false
	video.visible = false
	letterbox.color = Color(0, 0, 0, 1)
	Story.finish_current()
