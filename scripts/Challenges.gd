extends VBoxContainer


var _labels: Dictionary[Stockpile.ItemType, Label] = {}


func _ready() -> void:
	Catalog.building_set_changed.connect(_refresh)
	Stockpile.changed.connect(_refresh)
	Stockpile.challenge_updated.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for item in Stockpile.ItemTypes:
		pass

		if item in _labels:
			if Stockpile.is_unavailable_story_item(item) or not Stockpile.is_visible(item):
				_labels[item].queue_free()
				_labels.erase(item)
			else:
				_labels[item].text = _make_label_text(item)

		elif Stockpile.is_available_story_item(item) and Stockpile.is_visible(item):
			var label := Label.new()
			label.text = _make_label_text(item)
			add_child(label)
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
