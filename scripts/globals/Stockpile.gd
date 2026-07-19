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

const _ITEM_NAMES: Dictionary[ItemType, String] = {
	ItemType.RAW_TITANIUM: "Compacted Titanium Alloy",
	ItemType.HOSHIUMIUM: "Hoshiumium",

	ItemType.LUMBER: "Lumber",
	ItemType.PLANKS: "Planks",
	ItemType.CLAY: "Clay",
	ItemType.BRICKS: "Fired Clay Bricks",

	ItemType.RAW_BRASS: "Cu-Zn Sulfide Deposit",
	ItemType.BRASS_INGOTS: "Brass Ingots",
	ItemType.MECHANICAL_COMPONENTS: "Mechanical Components",

	ItemType.RAW_ELECTRUM: "Compacted Electrum",
	ItemType.ELECTRUM_WIRE: "Electrum Wire",

	ItemType.SAND: "Silica Sand",
	ItemType.EVAPORITES: "Evaporites",
	ItemType.WATER: "Mineral Water",

	ItemType.PETROCHEMICALS: "Petrochemicals",
	ItemType.ACRYLIC: "Acrylic Plastic",
	ItemType.PLASTIC: "Multi-Purpose Polymer",

	ItemType.RAW_CUPRONICKEL: "Cu-Ni Sulfide Deposit",
	ItemType.CUPRONICKEL_INGOTS: "Cupronickel Ingots",
	ItemType.FLUID_HARDWARE: "Fluid Hardware Package",

	ItemType.BATTERY_ACID: "Sulfuric Acid",
	ItemType.POWER_CELLS: "Power Cells",

	ItemType.SEMICONDUCTORS: "Semiconductor Precursors",
	ItemType.INTEGRATED_CIRCUITS: "Integrated Circuits",

	ItemType.ELECTRONIC_COMPONENTS: "Electronic Components",
	ItemType.INDUSTRIAL_CONTROLLERS: "Industrial Computer Modules",
	ItemType.ELECTRONIC_ACTUATORS: "Assorted Actuators",

	ItemType.JELLY_STANDEES: "Jelly Standees",
	ItemType.COFFEE_CHERRIES: "Sumatra Cherries",
	ItemType.JELLY_COFFEE: "Jelly Coffee",

	ItemType.STEAM_ENGINE: "Steam Engine",
	ItemType.WHITE_PAINT: "White Paint",

	ItemType.PC_RAM: "Phase™ RAM",
	ItemType.PC_CPU: "Phase™ CPU",
	ItemType.PC_GPU: "Phase™ GPU",
	ItemType.PC_MOTHERBOARD: "PC Motherboard",
	ItemType.PC_POWER_SUPPLY: "PC Power Supply",
	ItemType.PC_GLASS: "Tempered Glass Panel",
	ItemType.PC_CASE: "PC Case",
	ItemType.PC_FANS: "PC Fans",
	ItemType.PC_AIO_COOLER: "AIO Cooler",
	ItemType.PC_PC: "Personal Computer",
}

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
			_current[item] = 9999
			_produced[item] = 9999
			_seen[item] = true

	_register_challenges()


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


func get_display_name(item: ItemType) -> String:
	if not _ITEM_NAMES.has(item):
		return "???"
	return _ITEM_NAMES[item]


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
