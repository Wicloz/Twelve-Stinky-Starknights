extends Node
signal changed


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
	FLUID_PIPES,
	PRESSURE_VESSELS,

	HOSHIUMIUM,
	JELLY_STANDEES,
}

var ItemTypes: Array[ItemType] = []

const _ITEM_NAMES: Dictionary[ItemType, String] = {
	ItemType.RAW_TITANIUM: "Compacted Titanium",

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
	ItemType.FLUID_PIPES: "Fluid Pipes",
	ItemType.PRESSURE_VESSELS: "Pressure Vessels",

	ItemType.HOSHIUMIUM: "Hoshiumium",
	ItemType.JELLY_STANDEES: "Jelly Standees",
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
