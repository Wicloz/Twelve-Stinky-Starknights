class_name ConstructionPanel
extends PanelContainer
signal building_selected(item: CatalogItem)


@onready var _columns: HBoxContainer = $Margin/Scroll/Columns

const ROWS := 2
const CELL := Vector2(60, 85)

var _shown: Array[CatalogItem] = []


func _ready() -> void:
	Stockpile.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var items := Catalog.get_unlocked_buildings()

	if items.size() == _shown.size():
		return

	for item in items:
		if item in _shown:
			continue

		_shown.append(item)
		_last_open_column().add_child(_make_button(item))


func _last_open_column() -> VBoxContainer:
	if _columns.get_child_count() > 0:
		var last: VBoxContainer = _columns.get_child(-1)
		if last.get_child_count() < ROWS:
			return last

	var column := VBoxContainer.new()
	_columns.add_child(column)
	return column


func _make_button(item: CatalogItem) -> Button:
	var button := Button.new()

	button.custom_minimum_size = CELL
	button.custom_maximum_size = CELL

	button.tooltip_text = item.display_name + "\n"
	for resource in item.cost:
		button.tooltip_text += "\n%s: %d" % [Stockpile.get_display_name(resource), item.cost[resource]]

	button.icon = item.get_icon()
	button.expand_icon = true

	button.pressed.connect(func() -> void:
		building_selected.emit(item)
	)

	return button
