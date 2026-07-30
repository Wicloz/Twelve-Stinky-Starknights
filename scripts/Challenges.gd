extends VBoxContainer


## Edge length the icon in front of each challenge name is drawn at.
@export var icon_size: int = 20

var _rows: Dictionary[Stockpile.ItemType, Control] = {}
var _labels: Dictionary[Stockpile.ItemType, Label] = {}


func _ready() -> void:
	Catalog.building_set_changed.connect(_refresh)
	Stockpile.changed.connect(_refresh)
	Stockpile.challenge_updated.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for item in Stockpile.ItemTypes:
		if item in _rows:
			if Stockpile.is_unavailable_story_item(item) or not Stockpile.is_visible(item):
				_rows[item].queue_free()
				_rows.erase(item)
				_labels.erase(item)
			else:
				_labels[item].text = _make_label_text(item)

		elif Stockpile.is_available_story_item(item) and Stockpile.is_visible(item):
			_add_row(item)


func _add_row(item: Stockpile.ItemType) -> void:
	var row := HBoxContainer.new()
	add_child(row)

	var icon := TextureRect.new()
	icon.texture = Stockpile.get_icon(item)
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var label := Label.new()
	label.text = _make_label_text(item)
	row.add_child(label)

	_rows[item] = row
	_labels[item] = label


func _make_label_text(item: Stockpile.ItemType) -> String:
	var warehouse: bool = Catalog.currently_exists(Warehouse)
	var text: String = ""

	if not warehouse:
		text += "%s: ???" % Stockpile.get_display_name(item)
	else:
		text += "%s: %d" % [Stockpile.get_display_name(item), Stockpile.get_cumulative(item)]

	var limit = Stockpile.get_challenge_limit(item)
	if limit is int:
		if not warehouse:
			text += " / ???"
		else:
			text += " / %d" % limit

	return text
