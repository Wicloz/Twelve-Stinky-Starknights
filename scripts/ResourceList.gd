extends VBoxContainer


var _labels: Dictionary[Stockpile.ItemType, Label] = {}
var _seen: Dictionary[Stockpile.ItemType, bool] = {}


func _ready() -> void:
	for item in Stockpile.ItemTypes:
		var label := Label.new()
		add_child(label)
		_labels[item] = label
		_seen[item] = false
	Stockpile.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for item in Stockpile.ItemTypes:
		var amount = Stockpile.get_amount(item)

		if amount > 0:
			_seen[item] = true

		if _seen[item]:
			_labels[item].text = "%s: %d" % [Stockpile.get_display_name(item), Stockpile.get_amount(item)]
			_labels[item].show()

		else:
			_labels[item].hide()
