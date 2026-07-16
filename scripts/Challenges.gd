extends VBoxContainer


var _labels: Dictionary[Stockpile.ItemType, Label] = {}


func _ready() -> void:
	Stockpile.changed.connect(_refresh)
	Stockpile.challenge_updated.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for item in Stockpile.ItemTypes:
		pass

		if item in _labels:
			if Stockpile.is_unavailable_story_item(item):
				_labels[item].queue_free()
				_labels.erase(item)
			else:
				_labels[item].text = _make_label_text(item)

		elif Stockpile.is_available_story_item(item):
			var label := Label.new()
			label.text = _make_label_text(item)
			add_child(label)
			_labels[item] = label


func _make_label_text(item: Stockpile.ItemType) -> String:
	var text := "%s: %d" % [Stockpile.get_display_name(item), Stockpile.get_cumulative(item)]

	var limit = Stockpile.get_challenge_limit(item)
	if limit is int:
		text += " / %d" % limit

	return text
