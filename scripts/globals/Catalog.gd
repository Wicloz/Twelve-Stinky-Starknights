extends Node


var _catalog: Array[CatalogItem] = []
var _ever_finished_construction: Dictionary[CatalogItem, bool] = {}


func _ready() -> void:
    var item: CatalogItem

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/BrassFurnace.tscn")
    item.cost[Stockpile.ItemType.BRICKS] = 100
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 50
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/CupronickelFurnace.tscn")
    item.cost[Stockpile.ItemType.BRICKS] = 100
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 50
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/Sawmill.tscn")
    item.cost[Stockpile.ItemType.BRICKS] = 10
    item.cost[Stockpile.ItemType.LUMBER] = 10
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/Brickworks.tscn")
    item.cost[Stockpile.ItemType.BRICKS] = 10
    item.cost[Stockpile.ItemType.LUMBER] = 10
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/Pitmine.tscn")
    item.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 10
    item.cost[Stockpile.ItemType.PLANKS] = 200
    item.allowed_deposits = [
        Stockpile.ItemType.RAW_TITANIUM,
        Stockpile.ItemType.CLAY,
        Stockpile.ItemType.RAW_BRASS,
        Stockpile.ItemType.RAW_ELECTRUM,
        Stockpile.ItemType.SAND,
        Stockpile.ItemType.RAW_CUPRONICKEL,
    ]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/MCFactory.tscn")
    item.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 10
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 400
    item.cost[Stockpile.ItemType.BRICKS] = 800
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/WireMill.tscn")
    item.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 10
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 400
    item.cost[Stockpile.ItemType.BRICKS] = 800
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/FluidHardwareFactory.tscn")
    item.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 10
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 400
    item.cost[Stockpile.ItemType.BRICKS] = 800
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/SiliconBouleComplex.tscn")
    item.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 10
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 400
    item.cost[Stockpile.ItemType.BRICKS] = 800
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/OilRig.tscn")
    item.cost[Stockpile.ItemType.FLUID_HARDWARE] = 20
    item.allowed_deposits = [Stockpile.ItemType.PETROCHEMICALS]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/Refinery.tscn")
    item.cost[Stockpile.ItemType.FLUID_HARDWARE] = 20
    item.allowed_deposits = [Stockpile.ItemType.NONE]


func building_finished_construction(item: CatalogItem) -> void:
    _ever_finished_construction[item] = true


func has_finished_construction(item: CatalogItem) -> bool:
    return _ever_finished_construction.get(item, false)


func get_unlocked_buildings() -> Array[CatalogItem]:
    return _catalog.filter(func(item: CatalogItem) -> bool:
        for resource in item.cost:
            if not Stockpile.is_seen(resource) or Stockpile.is_unavailable_story_item(resource):
                return false
        for resource in item.allowed_deposits:
            if Stockpile.is_unavailable_story_item(resource):
                return false
        for resource in item.get_items_produced():
            if Stockpile.is_unavailable_story_item(resource):
                return false
        for resource in item.get_items_consumed():
            if Stockpile.is_unavailable_story_item(resource):
                return false
        return true
    )
