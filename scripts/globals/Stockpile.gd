extends Node
signal changed


enum ItemType {
	NONE,
	ORE,
	INGOT,
	OIL,
	PLASTIC,
	LOGS,
}

var ItemTypes: Array[ItemType] = []

const _ITEM_NAMES: Dictionary[ItemType, String] = {
	ItemType.ORE: "Metal Ore",
	ItemType.INGOT: "Metal Ingot",
	ItemType.OIL: "Oil",
	ItemType.PLASTIC: "Plastic",
	ItemType.LOGS: "Logs",
}

var _amounts: Dictionary[ItemType, int] = {}


func _ready() -> void:
	for item in ItemType.values():
		if item != ItemType.NONE:
			ItemTypes.append(item)
			_amounts[item] = 0


func add(item: ItemType, amount: int) -> void:
	_amounts[item] += amount
	changed.emit()


func add_bulk(items: Dictionary[ItemType, int]) -> void:
	for item in items:
		_amounts[item] += items[item]
	changed.emit()


func remove(item: ItemType, amount: int) -> void:
	_amounts[item] -= amount
	changed.emit()


func remove_bulk(items: Dictionary[ItemType, int]) -> void:
	for item in items:
		_amounts[item] -= items[item]
	changed.emit()


func get_amount(item: ItemType) -> int:
	return _amounts[item]


func get_display_name(item: ItemType) -> String:
	if not _ITEM_NAMES.has(item):
		return "???"
	return _ITEM_NAMES[item]
