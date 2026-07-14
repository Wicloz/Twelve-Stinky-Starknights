extends Node
signal changed


enum ItemType {
	NONE,

	IRON_ORE,
	IRON_INGOT,
	LUMBER,
	PLANK,
	CLAY,
	BRICK,

	RAW_BRASS,
	BRASS_INGOT,
	MECHANICAL_COMPONENTS,

	RAW_ELECTRUM,
	ELECTRUM_WIRE,
}

var ItemTypes: Array[ItemType] = []

const _ITEM_NAMES: Dictionary[ItemType, String] = {
	ItemType.IRON_ORE: "Iron Ore",
	ItemType.IRON_INGOT: "Iron Ingot",
	ItemType.LUMBER: "Lumber",
	ItemType.PLANK: "Plank",
	ItemType.CLAY: "Clay",
	ItemType.BRICK: "Fired Clay Brick",

	ItemType.RAW_BRASS: "Cu-Zn Sulfide Deposit",
	ItemType.BRASS_INGOT: "Brass Ingot",
	ItemType.MECHANICAL_COMPONENTS: "Mechanical Components",

	ItemType.RAW_ELECTRUM: "Compacted Electrum",
	ItemType.ELECTRUM_WIRE: "Electrum Wire",
}

var _amounts: Dictionary[ItemType, int] = {}
var _seen: Dictionary[ItemType, bool] = {}


func _ready() -> void:
	for item in ItemType.values():
		if item != ItemType.NONE:
			ItemTypes.append(item)
			_amounts[item] = 99999
			_seen[item] = true


func add(item: ItemType, amount: int) -> void:
	_amounts[item] += amount
	_seen[item] = true
	changed.emit()


func add_bulk(items: Dictionary[ItemType, int]) -> void:
	for item in items:
		_amounts[item] += items[item]
		_seen[item] = true
	changed.emit()


func remove(item: ItemType, amount: int) -> void:
	_amounts[item] -= amount
	_seen[item] = true
	changed.emit()


func remove_bulk(items: Dictionary[ItemType, int]) -> void:
	for item in items:
		_amounts[item] -= items[item]
		_seen[item] = true
	changed.emit()


func get_amount(item: ItemType) -> int:
	return _amounts[item]


func get_display_name(item: ItemType) -> String:
	if not _ITEM_NAMES.has(item):
		return "???"
	return _ITEM_NAMES[item]


func is_seen(item: ItemType) -> bool:
	return _seen[item]
