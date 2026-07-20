extends VBoxContainer


@export var label_settings: LabelSettings
## Bottom panels whose left edge should stay flush against the (variable-width)
## resource list, so they fill only the space to its right.
@export var bottom_panels: Array[Control] = []
## The left-anchored container holding this list; its right edge drives the
## panel offsets (it owns the padding + scroll area, so it spans their width).
@export var list_container: Control
var _labels: Dictionary[Stockpile.ItemType, Label] = {}


func _ready() -> void:
	Stockpile.changed.connect(_refresh)
	resized.connect(_sync_panel_offsets)
	list_container.resized.connect(_sync_panel_offsets)
	_refresh()
	_sync_panel_offsets()


# Anchors can't reference a sibling's size, so push the list block's right edge
# onto the bottom panels whenever the list or the viewport changes width.
func _sync_panel_offsets() -> void:
	var edge := list_container.position.x + list_container.size.x
	for panel in bottom_panels:
		panel.offset_left = edge


func _refresh() -> void:
	for item in Stockpile.ItemTypes:
		if item in _labels:
			_labels[item].text = _make_label_text(item)

		elif not Stockpile.is_story_item(item) and Stockpile.is_seen(item):
			var label := Label.new()
			label.label_settings = label_settings
			label.text = _make_label_text(item)
			add_child(label)
			_labels[item] = label


func _make_label_text(item: Stockpile.ItemType) -> String:
	return "%s: %d" % [Stockpile.get_display_name(item), Stockpile.get_amount(item)]
