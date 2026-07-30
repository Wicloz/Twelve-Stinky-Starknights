extends GridContainer


@export var label_settings: LabelSettings
## Edge length the icon of every cell is squashed to.
@export var icon_size: int = 24
## Width every cell is pinned to; the column count is derived from it. Wide
## enough for the icon, the outline insets and a count of about eight digits.
@export var cell_width: int = 112

var _cells: Dictionary[Stockpile.ItemType, Control] = {}
var _labels: Dictionary[Stockpile.ItemType, Label] = {}


func _ready() -> void:
	Stockpile.changed.connect(_refresh)
	resized.connect(_sync_columns)
	_build_cells()
	_sync_columns()
	_refresh()


# Every item gets a cell up front and is merely hidden until it is discovered.
# Hidden children take up no slot, so the grid stays compact while the cells
# that are showing keep their enum order instead of their discovery order.
func _build_cells() -> void:
	# The text outline is drawn outwards from the glyphs, so it needs this much
	# room around them or whatever clips the count eats into it.
	var outline_room := 0 if label_settings == null else label_settings.outline_size

	for item in Stockpile.ItemTypes:
		var cell := HBoxContainer.new()
		cell.visible = false
		cell.custom_minimum_size = Vector2(cell_width, 0)
		cell.size_flags_horizontal = Control.SIZE_FILL
		cell.tooltip_text = Stockpile.get_display_name(item)
		# Labels and TextureRects ignore the mouse, so the tooltip has to live
		# on the cell itself to have anything to hover over.
		cell.mouse_filter = Control.MOUSE_FILTER_STOP

		# The icon is optional; a TextureRect with nothing in it draws nothing
		# but still holds its slot, which keeps the counts lined up in a column
		# whether or not the items above and below have artwork yet.
		var icon := TextureRect.new()
		icon.texture = Stockpile.get_icon(item)
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.add_child(icon)

		# Cells are a fixed width so the column count stays predictable, which
		# means an overlong count has to be clipped rather than widen the cell.
		# A plain Control -- unlike a container -- does not adopt its child's
		# minimum size, so the label cannot push the cell wider, and clipping
		# happens at the slot's edge instead of at the label's own rect. That
		# distinction is the whole point: the label's rect starts flush with the
		# first glyph, so clipping there always shears the outline's left edge
		# off, no matter how the label is positioned.
		var slot := Control.new()
		slot.clip_contents = true
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.custom_minimum_size = Vector2(0, icon_size + outline_room)
		cell.add_child(slot)

		var label := Label.new()
		label.label_settings = label_settings
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.offset_left = outline_room

		add_child(cell)
		_cells[item] = cell
		_labels[item] = label


# The grid is as wide as the viewport allows, so the column count has to follow
# it. Only assigned when it actually changes, otherwise the relayout this
# triggers would call us straight back.
func _sync_columns() -> void:
	var separation := get_theme_constant("h_separation")
	var wanted := maxi(1, floori((size.x + separation) / float(cell_width + separation)))
	if wanted != columns:
		columns = wanted


func _refresh() -> void:
	for item in Stockpile.ItemTypes:
		if not _cells[item].visible:
			if Stockpile.is_story_item(item) or not Stockpile.is_seen(item):
				continue
			_cells[item].visible = true

		_labels[item].text = str(Stockpile.get_amount(item))
