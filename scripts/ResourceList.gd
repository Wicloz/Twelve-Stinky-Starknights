extends VBoxContainer


@export var label_settings: LabelSettings
var _labels: Dictionary[Stockpile.ItemType, Label] = {}


func _ready() -> void:
	Stockpile.changed.connect(_refresh)
	_refresh()


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
