extends VBoxContainer


var _labels: Dictionary[Stockpile.ItemType, Label] = {}


func _ready() -> void:
	for item in Stockpile.ItemTypes:
		var label := Label.new()
		add_child(label)
		_labels[item] = label
		label.hide()

	Stockpile.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for item in Stockpile.ItemTypes:
		if Stockpile.is_seen(item) and not Stockpile.is_story_item(item):
			_labels[item].text = "%s: %d" % [Stockpile.get_display_name(item), Stockpile.get_amount(item)]
			_labels[item].show()
