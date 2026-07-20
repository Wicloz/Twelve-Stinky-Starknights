extends Node
signal building_set_changed


var _catalog: Array[CatalogItem] = []
var _ever_finished_construction: Dictionary[Script, bool] = {}
var _amount_constructed: Dictionary[Script, int] = {}


func _ready() -> void:
    var item: CatalogItem

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/Warehouse.tscn")
    item.cost[Stockpile.ItemType.CLAY] = 100
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 100
    item.allowed_deposits = [Stockpile.ItemType.NONE]

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
    item.always_unlocked = true

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/Brickworks.tscn")
    item.cost[Stockpile.ItemType.BRICKS] = 10
    item.cost[Stockpile.ItemType.LUMBER] = 10
    item.allowed_deposits = [Stockpile.ItemType.NONE]
    item.always_unlocked = true

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

    item.scene = preload("res://objects/buildings/MechanicalComponentFactory.tscn")
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

    item.scene = preload("res://objects/buildings/SemiconductorFoundry.tscn")
    item.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 10
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 400
    item.cost[Stockpile.ItemType.BRICKS] = 800
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/OilRig.tscn")
    item.cost[Stockpile.ItemType.FLUID_HARDWARE] = 20
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 400
    item.allowed_deposits = [Stockpile.ItemType.PETROCHEMICALS]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/PumpingStation.tscn")
    item.cost[Stockpile.ItemType.FLUID_HARDWARE] = 20
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 400
    item.allowed_deposits = [Stockpile.ItemType.WATER]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/EvaporationBasin.tscn")
    item.cost[Stockpile.ItemType.FLUID_HARDWARE] = 20
    item.cost[Stockpile.ItemType.CLAY] = 400
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/Refinery.tscn")
    item.cost[Stockpile.ItemType.FLUID_HARDWARE] = 20
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 400
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/PowerCellFactory.tscn")
    item.cost[Stockpile.ItemType.FLUID_HARDWARE] = 10
    item.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 10
    item.cost[Stockpile.ItemType.BRICKS] = 800
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/StarfallSite.tscn")
    item.allowed_deposits = [Stockpile.ItemType.HOSHIUMIUM]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/IntegratedCircuitFab.tscn")
    item.cost[Stockpile.ItemType.FLUID_HARDWARE] = 20
    item.cost[Stockpile.ItemType.ELECTRONIC_COMPONENTS] = 20
    item.cost[Stockpile.ItemType.PLASTIC] = 400
    item.cost[Stockpile.ItemType.BRICKS] = 400
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 400
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/ElectronicComponentFactory.tscn")
    item.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 10
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 400
    item.cost[Stockpile.ItemType.BRICKS] = 800
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/IndustrialControllerFactory.tscn")
    item.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 10
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 400
    item.cost[Stockpile.ItemType.BRICKS] = 800
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/ElectronicActuatorFactory.tscn")
    item.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 10
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 400
    item.cost[Stockpile.ItemType.BRICKS] = 800
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/JellyStandeeProductionLine.tscn")
    item.cost[Stockpile.ItemType.FLUID_HARDWARE] = 2
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 400
    item.cost[Stockpile.ItemType.BRICKS] = 800
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/SumatraCoffeeFarm.tscn")
    item.cost[Stockpile.ItemType.BRASS_INGOTS] = 10
    item.cost[Stockpile.ItemType.PLANKS] = 200
    item.cost[Stockpile.ItemType.LUMBER] = 200
    item.allowed_deposits = [Stockpile.ItemType.NONE]

    item = CatalogItem.new()
    _catalog.append(item)

    item.scene = preload("res://objects/buildings/JellyCoffeeBrewery.tscn")
    item.cost[Stockpile.ItemType.FLUID_HARDWARE] = 2
    item.cost[Stockpile.ItemType.RAW_TITANIUM] = 400
    item.cost[Stockpile.ItemType.BRICKS] = 800
    item.allowed_deposits = [Stockpile.ItemType.NONE]


func building_finished_construction(type: Script) -> void:
    _ever_finished_construction[type] = true
    _amount_constructed[type] = _amount_constructed.get(type, 0) + 1
    building_set_changed.emit()


func building_destroyed(type: Script) -> void:
    _amount_constructed[type] = _amount_constructed.get(type, 0) - 1
    building_set_changed.emit()


func has_finished_construction(type: Script) -> bool:
    return _ever_finished_construction.get(type, false)


func currently_exists(type: Script) -> bool:
    return type in _amount_constructed and _amount_constructed[type] > 0


func get_unlocked_buildings() -> Array[CatalogItem]:
    return _catalog.filter(func(item: CatalogItem) -> bool:
        if item.always_unlocked:
            return true
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
