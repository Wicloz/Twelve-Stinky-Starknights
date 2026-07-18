extends Node
signal changed
signal challenge_updated


enum ItemType {
	NONE,

	RAW_TITANIUM,

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
	SILICON_BOULE,

	PETROCHEMICALS,
	ACRYLIC_PLASTIC,

	RAW_CUPRONICKEL,
	CUPRONICKEL_INGOTS,
	FLUID_HARDWARE,

	HOSHIUMIUM,
	JELLY_STANDEES,

	BATTERY_ACID,
	POWER_CELLS,
}

var ItemTypes: Array[ItemType] = []

const _ITEM_NAMES: Dictionary[ItemType, String] = {
	ItemType.NONE: "???",

	ItemType.RAW_TITANIUM: "Compacted Titanium Alloy",

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
	ItemType.SILICON_BOULE: "Silicon Boule",

	ItemType.PETROCHEMICALS: "Petrochemicals",
	ItemType.ACRYLIC_PLASTIC: "Acrylic Plastic",

	ItemType.RAW_CUPRONICKEL: "Cu-Ni Sulfide Deposit",
	ItemType.CUPRONICKEL_INGOTS: "Cupronickel Ingots",
	ItemType.FLUID_HARDWARE: "Fluid Hardware Package",

	ItemType.HOSHIUMIUM: "Hoshiumium",
	ItemType.JELLY_STANDEES: "Jelly Standees",

	ItemType.BATTERY_ACID: "Sulfuric Acid",
	ItemType.POWER_CELLS: "Power Cells",
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
			_current[item] = 0
			_produced[item] = 0
			_seen[item] = false

	_register_challenges()


func _register_challenges() -> void:
	_challenges[ItemType.JELLY_STANDEES] = Challenge.new()


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


func start_challenge(item: ItemType) -> void:
	_challenges[item].state = ChallengeState.ACTIVE
	challenge_updated.emit()


func get_challenge_limit(item: ItemType):
	if item not in _challenges:
		return false
	return _challenges[item].get_limit()
