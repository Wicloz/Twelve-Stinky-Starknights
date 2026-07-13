class_name ConstructionPanel
extends PanelContainer


@onready var _columns: HBoxContainer = $Margin/Scroll/Columns

const ROWS := 2
const CELL := Vector2(120, 120)

func _ready() -> void:
	Stockpile.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for node in _columns.get_children():
		node.queue_free()

	var items := Catalog.get_unlocked_buildings()
	var column: VBoxContainer = null
	for i in items.size():
		if i % ROWS == 0:
			column = VBoxContainer.new()
			_columns.add_child(column)
		column.add_child(_make_button(items[i]))


func _make_button(item: CatalogItem) -> Button:
	var button := Button.new()
	button.custom_minimum_size = CELL
	button.icon = item.texture
	button.tooltip_text = item.display_name
	return button
