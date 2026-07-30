extends Node
signal changed
signal challenge_updated


enum ItemType {
	NONE,

	RAW_TITANIUM,
	HOSHIUMIUM,

	LUMBER,
	PLANKS,
	CLAY,
	BRICKS,

	RAW_BRASS,
	BRASS_INGOTS,
	MECHANICAL_COMPONENTS,

	RAW_ELECTRUM,
	ELECTRUM_WIRE,

	SAND,
	EVAPORITES,
	WATER,

	PETROCHEMICALS,
	ACRYLIC,
	PLASTIC,

	RAW_CUPRONICKEL,
	CUPRONICKEL_INGOTS,
	FLUID_HARDWARE,

	BATTERY_ACID,
	POWER_CELLS,

	SEMICONDUCTORS,
	INTEGRATED_CIRCUITS,

	ELECTRONIC_COMPONENTS,
	INDUSTRIAL_CONTROLLERS,
	ELECTRONIC_ACTUATORS,

	JELLY_STANDEES,
	COFFEE_CHERRIES,
	JELLY_COFFEE,

	STEAM_ENGINE,
	WHITE_PAINT,

	PC_RAM,
	PC_CPU,
	PC_GPU,
	PC_MOTHERBOARD,
	PC_POWER_SUPPLY,
	PC_GLASS,
	PC_CASE,
	PC_FANS,
	PC_AIO_COOLER,
	PC_PC,
}

var ItemTypes: Array[ItemType] = []

var _item_map: Dictionary[ItemType, StockpileItem] = {}

var _current: Dictionary[ItemType, int] = {}
var _produced: Dictionary[ItemType, int] = {}
var _seen: Dictionary[ItemType, bool] = {}

enum ChallengeState {
	LOCKED,
	ACTIVE,
	COMPLETED,
}

var _challenges: Dictionary[ItemType, Challenge] = {}


func _ready() -> void:
	for item in ItemType.values():
		if item != ItemType.NONE:
			ItemTypes.append(item)
			_current[item] = 0
			_produced[item] = 0
			_seen[item] = false

	_register_items()
	_register_challenges()


func _register_items() -> void:
	var item: StockpileItem

	item = StockpileItem.new()
	_item_map[ItemType.RAW_TITANIUM] = item

	item.display_name = "Compacted Titanium Alloy"
	item.icon = preload("res://assets/stockpile/titanium.png")

	item = StockpileItem.new()
	_item_map[ItemType.HOSHIUMIUM] = item

	item.display_name = "Hoshiumium"
	item.icon = preload("res://assets/stockpile/hoshiumium.png")

	item = StockpileItem.new()
	_item_map[ItemType.LUMBER] = item

	item.display_name = "Lumber"
	item.icon = preload("res://assets/stockpile/lumber.svg")

	item = StockpileItem.new()
	_item_map[ItemType.PLANKS] = item

	item.display_name = "Planks"
	item.icon = preload("res://assets/stockpile/planks.svg")

	item = StockpileItem.new()
	_item_map[ItemType.CLAY] = item

	item.display_name = "Clay"
	item.icon = preload("res://assets/stockpile/clay.svg")

	item = StockpileItem.new()
	_item_map[ItemType.BRICKS] = item

	item.display_name = "Fired Clay Bricks"
	item.icon = preload("res://assets/stockpile/bricks.svg")

	item = StockpileItem.new()
	_item_map[ItemType.RAW_BRASS] = item

	item.display_name = "Cu-Zn Sulfide Deposit"
	item.icon = preload("res://assets/stockpile/cuzn.png")

	item = StockpileItem.new()
	_item_map[ItemType.BRASS_INGOTS] = item

	item.display_name = "Brass Ingots"
	item.icon = preload("res://assets/stockpile/brass_ingots.svg")

	item = StockpileItem.new()
	_item_map[ItemType.MECHANICAL_COMPONENTS] = item

	item.display_name = "Mechanical Components"
	item.icon = preload("res://assets/stockpile/mechanical_components.svg")

	item = StockpileItem.new()
	_item_map[ItemType.RAW_ELECTRUM] = item

	item.display_name = "Compacted Electrum"
	item.icon = preload("res://assets/stockpile/electrum.png")

	item = StockpileItem.new()
	_item_map[ItemType.ELECTRUM_WIRE] = item

	item.display_name = "Electrum Wire"
	item.icon = preload("res://assets/stockpile/electrum_wire.svg")

	item = StockpileItem.new()
	_item_map[ItemType.SAND] = item

	item.display_name = "Silica Sand"
	item.icon = preload("res://assets/stockpile/sand.svg")

	item = StockpileItem.new()
	_item_map[ItemType.EVAPORITES] = item

	item.display_name = "Evaporites"
	item.icon = preload("res://assets/stockpile/evaporites.svg")

	item = StockpileItem.new()
	_item_map[ItemType.WATER] = item

	item.display_name = "Mineral Water"
	item.icon = preload("res://assets/stockpile/water.svg")

	item = StockpileItem.new()
	_item_map[ItemType.PETROCHEMICALS] = item

	item.display_name = "Petrochemicals"
	item.icon = preload("res://assets/stockpile/petrochemicals.svg")

	item = StockpileItem.new()
	_item_map[ItemType.ACRYLIC] = item

	item.display_name = "Acrylic Plastic"
	item.icon = preload("res://assets/stockpile/acrylic.svg")

	item = StockpileItem.new()
	_item_map[ItemType.PLASTIC] = item

	item.display_name = "Multi-Purpose Polymer"
	item.icon = preload("res://assets/stockpile/plastic.svg")

	item = StockpileItem.new()
	_item_map[ItemType.RAW_CUPRONICKEL] = item

	item.display_name = "Cu-Ni Sulfide Deposit"
	item.icon = preload("res://assets/stockpile/cuni.png")

	item = StockpileItem.new()
	_item_map[ItemType.CUPRONICKEL_INGOTS] = item

	item.display_name = "Cupronickel Ingots"
	item.icon = preload("res://assets/stockpile/cupronickel_ingots.svg")

	item = StockpileItem.new()
	_item_map[ItemType.FLUID_HARDWARE] = item

	item.display_name = "Fluid Hardware Package"
	item.icon = preload("res://assets/stockpile/fluid_hardware.svg")

	item = StockpileItem.new()
	_item_map[ItemType.BATTERY_ACID] = item

	item.display_name = "Sulfuric Acid"
	item.icon = preload("res://assets/stockpile/sulfuric_acid.svg")

	item = StockpileItem.new()
	_item_map[ItemType.POWER_CELLS] = item

	item.display_name = "Power Cells"
	item.icon = preload("res://assets/stockpile/power_cells.svg")

	item = StockpileItem.new()
	_item_map[ItemType.SEMICONDUCTORS] = item

	item.display_name = "Semiconductor Precursors"
	item.icon = preload("res://assets/stockpile/semiconductors.svg")

	item = StockpileItem.new()
	_item_map[ItemType.INTEGRATED_CIRCUITS] = item

	item.display_name = "Integrated Circuits"
	item.icon = preload("res://assets/stockpile/integrated_circuits.svg")

	item = StockpileItem.new()
	_item_map[ItemType.ELECTRONIC_COMPONENTS] = item

	item.display_name = "Electronic Components"
	item.icon = preload("res://assets/stockpile/electronic_components.svg")

	item = StockpileItem.new()
	_item_map[ItemType.INDUSTRIAL_CONTROLLERS] = item

	item.display_name = "Industrial Computer Modules"
	item.icon = preload("res://assets/stockpile/industrial_controllers.svg")

	item = StockpileItem.new()
	_item_map[ItemType.ELECTRONIC_ACTUATORS] = item

	item.display_name = "Assorted Actuators"
	item.icon = preload("res://assets/stockpile/actuators.svg")

	item = StockpileItem.new()
	_item_map[ItemType.JELLY_STANDEES] = item

	item.display_name = "Jelly Standees"
	item.icon = preload("res://assets/stockpile/standee.png")

	item = StockpileItem.new()
	_item_map[ItemType.COFFEE_CHERRIES] = item

	item.display_name = "Sumatra Cherries"
	item.icon = preload("res://assets/stockpile/coffee_cherries.svg")

	item = StockpileItem.new()
	_item_map[ItemType.JELLY_COFFEE] = item

	item.display_name = "Jelly Coffee"
	item.icon = preload("res://assets/stockpile/coffee.png")

	item = StockpileItem.new()
	_item_map[ItemType.STEAM_ENGINE] = item

	item.display_name = "Steam Engine"
	item.icon = preload("res://assets/stockpile/steam_engine.svg")

	item = StockpileItem.new()
	_item_map[ItemType.WHITE_PAINT] = item

	item.display_name = "White Paint"
	item.icon = preload("res://assets/stockpile/white_paint.svg")

	item = StockpileItem.new()
	_item_map[ItemType.PC_RAM] = item

	item.display_name = "Phase™ RAM"

	item = StockpileItem.new()
	_item_map[ItemType.PC_CPU] = item

	item.display_name = "Phase™ CPU"

	item = StockpileItem.new()
	_item_map[ItemType.PC_GPU] = item

	item.display_name = "Phase™ GPU"

	item = StockpileItem.new()
	_item_map[ItemType.PC_MOTHERBOARD] = item

	item.display_name = "PC Motherboard"

	item = StockpileItem.new()
	_item_map[ItemType.PC_POWER_SUPPLY] = item

	item.display_name = "PC Power Supply"

	item = StockpileItem.new()
	_item_map[ItemType.PC_GLASS] = item

	item.display_name = "Tempered Glass Panel"

	item = StockpileItem.new()
	_item_map[ItemType.PC_CASE] = item

	item.display_name = "PC Case"

	item = StockpileItem.new()
	_item_map[ItemType.PC_FANS] = item

	item.display_name = "PC Fans"

	item = StockpileItem.new()
	_item_map[ItemType.PC_AIO_COOLER] = item

	item.display_name = "AIO Cooler"

	item = StockpileItem.new()
	_item_map[ItemType.PC_PC] = item

	item.display_name = "Personal Computer"
	item.icon = preload("res://assets/stockpile/pc.svg")


func _register_challenges() -> void:
	_challenges[ItemType.JELLY_STANDEES] = Challenge.new()
	_challenges[ItemType.JELLY_COFFEE] = Challenge.new()

	_challenges[ItemType.STEAM_ENGINE] = Challenge.new(1)
	_challenges[ItemType.WHITE_PAINT] = Challenge.new(216)

	_challenges[ItemType.PC_RAM] = Challenge.new(4, false)
	_challenges[ItemType.PC_CPU] = Challenge.new(1, false)
	_challenges[ItemType.PC_GPU] = Challenge.new(1, false)
	_challenges[ItemType.PC_MOTHERBOARD] = Challenge.new(1, false)
	_challenges[ItemType.PC_POWER_SUPPLY] = Challenge.new(1, false)
	_challenges[ItemType.PC_GLASS] = Challenge.new(1, false)
	_challenges[ItemType.PC_CASE] = Challenge.new(1, false)
	_challenges[ItemType.PC_FANS] = Challenge.new(9, false)
	_challenges[ItemType.PC_AIO_COOLER] = Challenge.new(1, false)
	_challenges[ItemType.PC_PC] = Challenge.new(1)


func _add_once(item: ItemType, amount: int) -> void:
	_current[item] += amount
	_produced[item] += amount
	_seen[item] = true

	if item not in _challenges:
		return

	var challenge := _challenges[item]

	if challenge.state == ChallengeState.COMPLETED:
		return

	if challenge.is_limit_reached(_produced[item]):
		challenge.state = ChallengeState.COMPLETED
		challenge_updated.emit()


func add(item: ItemType, amount: int) -> void:
	_add_once(item, amount)
	changed.emit()


func add_bulk(items: Dictionary[ItemType, int]) -> void:
	for item in items:
		_add_once(item, items[item])
	changed.emit()


func _remove_once(item: ItemType, amount: int) -> void:
	_current[item] -= amount
	_seen[item] = true


func remove(item: ItemType, amount: int) -> void:
	_remove_once(item, amount)
	changed.emit()


func remove_bulk(items: Dictionary[ItemType, int]) -> void:
	for item in items:
		_remove_once(item, items[item])
	changed.emit()


func get_amount(item: ItemType) -> int:
	return _current[item]


func get_cumulative(item: ItemType) -> int:
	return _produced[item]


func get_item(item: ItemType) -> StockpileItem:
	return _item_map[item]


func get_display_name(item: ItemType) -> String:
	if not _item_map.has(item):
		return "???"
	return _item_map[item].display_name


func get_icon(item: ItemType) -> Texture2D:
	if not _item_map.has(item):
		return null
	return _item_map[item].icon


func is_seen(item: ItemType) -> bool:
	return _seen[item]


func is_story_item(item: ItemType) -> bool:
	return item in _challenges


func is_unavailable_story_item(item: ItemType) -> bool:
	return item in _challenges and _challenges[item].state != ChallengeState.ACTIVE


func is_available_story_item(item: ItemType) -> bool:
	return item in _challenges and _challenges[item].state == ChallengeState.ACTIVE


func is_challenge_completed(item: ItemType) -> bool:
	if item not in _challenges:
		return false
	return _challenges[item].state == ChallengeState.COMPLETED


func start_challenge(item: ItemType) -> void:
	_challenges[item].state = ChallengeState.ACTIVE
	challenge_updated.emit()


func get_challenge_limit(item: ItemType):
	if item not in _challenges:
		return false
	return _challenges[item].get_limit()


func is_visible(item: ItemType) -> bool:
	if item in _challenges:
		return _challenges[item].is_shown()
	return true
