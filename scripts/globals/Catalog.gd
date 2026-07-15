extends Node


var _catalog: Array[CatalogItem] = []


func _ready() -> void:
    var item: CatalogItem

    item = CatalogItem.new()
    _catalog.append(item)

    item.display_name = "Build Brass Foundry"
    item.scene = preload("res://objects/buildings/BrassFurnace.tscn")
    item.texture = preload("res://assets/buildings/furnace2.png")
    item.cost[Stockpile.ItemType.BRICKS] = 100
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 50
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.display_name = "Build Cupronickel Foundry"
    item.scene = preload("res://objects/buildings/CupronickelFurnace.tscn")
    item.texture = preload("res://assets/buildings/furnace2.png")
    item.cost[Stockpile.ItemType.BRICKS] = 100
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 50
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.display_name = "Build Sawmill"
    item.scene = preload("res://objects/buildings/Sawmill.tscn")
    item.texture = preload("res://assets/buildings/sawmill.png")
    item.cost[Stockpile.ItemType.BRICKS] = 10
    item.cost[Stockpile.ItemType.LUMBER] = 10
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.display_name = "Build Brickworks"
    item.scene = preload("res://objects/buildings/Brickworks.tscn")
    item.texture = preload("res://assets/buildings/brickworks.png")
    item.cost[Stockpile.ItemType.BRICKS] = 10
    item.cost[Stockpile.ItemType.LUMBER] = 10
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.display_name = "Build Logging Camp"
    item.scene = preload("res://objects/buildings/LoggingCamp.tscn")
    item.texture = preload("res://assets/buildings/logging_camp.png")
    item.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 10
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 10
    item.allowed_deposits = [Stockpile.ItemType.LUMBER]

    item = CatalogItem.new()
    _catalog.append(item)

    item.display_name = "Build Pitmine"
    item.scene = preload("res://objects/buildings/Pitmine.tscn")
    item.texture = preload("res://assets/buildings/pitmine.png")
    item.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 10
    item.cost[Stockpile.ItemType.PLANKS] = 100
    item.allowed_deposits = [
        Stockpile.ItemType.RAW_TITANIUM,
        Stockpile.ItemType.CLAY,
        Stockpile.ItemType.RAW_BRASS,
        Stockpile.ItemType.RAW_ELECTRUM,
        Stockpile.ItemType.SAND,
        Stockpile.ItemType.RAW_CUPRONICKEL,
    ]


func get_unlocked_buildings() -> Array[CatalogItem]:
    return _catalog.filter(func(item: CatalogItem) -> bool:
        for resource in item.cost:
            if Stockpile.is_seen(resource):
                return true
        return false
    )
