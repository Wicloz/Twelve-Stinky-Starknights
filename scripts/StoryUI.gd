extends PanelContainer


@onready var video := $VBox/CutsceneViewer/VideoAspect/VideoDisplay
@onready var image := $VBox/CutsceneViewer/ImageAspect/ImageDisplay
@onready var narration := $VBox/Narration
@onready var video_aspect := $VBox/CutsceneViewer/VideoAspect
@onready var image_aspect := $VBox/CutsceneViewer/ImageAspect

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

	_reveal_text(cutscene.text, cutscene.duration)


func _fit_media(aspect: AspectRatioContainer, px: Vector2) -> void:
	if px.y > 0.0:
		aspect.ratio = px.x / px.y


func _reveal_text(bbcode: String, duration: float) -> void:
	var from: int = narration.get_total_character_count()
	narration.append_text(bbcode + "\n\n")
	var to: int = narration.get_total_character_count() - 2

	if duration <= 0.0 or to <= from:
		narration.visible_characters = -1
		_on_text_revealed()
		return

	narration.visible_characters = from

	_reveal = create_tween()
	_reveal.tween_property(narration, "visible_characters", to, duration)
	_reveal.finished.connect(func() -> void:
		narration.visible_characters = -1
		_on_text_revealed()
	)


func _on_text_revealed() -> void:
	image.visible = false
	video.visible = false
	Story.finish_current()
