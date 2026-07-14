class_name ConstructionPanel
extends PanelContainer
signal building_selected(item: CatalogItem)


@onready var _columns: HBoxContainer = $Margin/Scroll/Columns

const ROWS := 2
const CELL := Vector2(140, 140)

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
	button.custom_maximum_size = CELL
	button.tooltip_text = item.display_name

	button.icon = item.texture
	button.vertical_icon_alignment = 1
	button.icon_alignment = 1

	button.pressed.connect(func() -> void:
		building_selected.emit(item)
	)

	return button
