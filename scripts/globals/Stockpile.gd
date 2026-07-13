extends Node
signal changed


enum ItemType {
	NONE,

	ORE,
	INGOTS,
	LUMBER,
	PLANKS,
	CLAY,
	BRICKS,
}

var ItemTypes: Array[ItemType] = []

const _ITEM_NAMES: Dictionary[ItemType, String] = {
	ItemType.ORE: "Metal Ore",
	ItemType.INGOTS: "Metal Ingots",
	ItemType.LUMBER: "Lumber",
	ItemType.PLANKS: "Planks",
	ItemType.CLAY: "Clay",
	ItemType.BRICKS: "Bricks",
}

var _amounts: Dictionary[ItemType, int] = {}
var _seen: Dictionary[ItemType, bool] = {}


func _ready() -> void:
	for item in ItemType.values():
		if item != ItemType.NONE:
			ItemTypes.append(item)
			_amounts[item] = 0
			_seen[item] = false


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
