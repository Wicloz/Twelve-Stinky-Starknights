extends VBoxContainer


@export var label_settings: LabelSettings
## Bottom panels whose left edge should stay flush against the (variable-width)
## resource list, so they fill only the space to its right.
@export var bottom_panels: Array[Control] = []
var _labels: Dictionary[Stockpile.ItemType, Label] = {}

# The left-anchored container holding the padding + scroll area; its right edge
# is where the bottom panels begin. Resolved from the tree (not an exported
# NodePath) so it can't be dropped when the editor re-saves the scene.
@onready var _list_panel: Control = _find_list_panel()


func _ready() -> void:
	Stockpile.changed.connect(_refresh)
	resized.connect(_sync_panel_offsets)
	_list_panel.resized.connect(_sync_panel_offsets)
	_refresh()
	_sync_panel_offsets()


# The outermost Control between this list and the UI CanvasLayer.
func _find_list_panel() -> Control:
	var node: Node = self
	while node.get_parent() != null and node.get_parent() is not CanvasLayer:
		node = node.get_parent()
	return node as Control


# Anchors can't reference a sibling's size, so push the list block's right edge
# onto the bottom panels whenever the list or the viewport changes width.
func _sync_panel_offsets() -> void:
	var edge := _list_panel.position.x + _list_panel.size.x
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
