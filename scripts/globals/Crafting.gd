extends Node


enum Capabilities {
	FURNACE,
	WORKBENCH,
	REFINERY,
	CLEANROOM,
	WIRE_MILL,
	INJECTION_MOLDING,
	LATHE, CNC_MILL,
	OVERHEAD_CRANE,
	SOLDERING_STATION,
	ASSEMBLY_STATION,
	LITHOGRAPHY,
}

enum RecipeType {
	MAKE_PLANKS,
	MAKE_BRICKS,
	MAKE_BRASS,
	MAKE_MECHANICAL_COMPONENTS,
	MAKE_CUPRONICKEL,
	MAKE_FLUID_HARDWARE,
	MAKE_ELECTRUM_WIRE,
	MAKE_SEMICONDUCTORS,
	OPERATE_REFINERY,
	MAKE_POWER_CELLS,
	MAKE_INTEGRATED_CIRCUITS,
	MAKE_ELECTRONIC_COMPONENTS,
	MAKE_INDUSTRIAL_CONTROLLERS,
	MAKE_JELLY_STANDEES,
	MAKE_EVAPORITES,
	MAKE_JELLY_COFFEE,
	MAKE_STEAM_ENGINE,

	MAKE_PC_GLASS,
	MAKE_PC_CASE,
	MAKE_PC_FANS,
	MAKE_PC_POWER_SUPPLY,
	MAKE_PC_MOTHERBOARD,
	MAKE_PC_RAM,
	MAKE_PC_CPU,
	MAKE_PC_GPU,
	MAKE_PC_AIO_COOLER,
	MAKE_PC,
}

var _recipe_map: Dictionary[RecipeType, Recipe] = {}


func get_recipe(recipe_type: RecipeType) -> Recipe:
	return _recipe_map[recipe_type]


func all_recipes() -> Array[Recipe]:
	return _recipe_map.values()


func recipes_for_workshop() -> Array[Recipe]:
	var result: Array[Recipe] = []

	for recipe in _recipe_map.values():
		var satisfied = true

		for capability in recipe.needs_capabilities:
			if not Workshop.capabilities.has(capability):
				satisfied = false
				break

		if not satisfied:
			continue

		for resource in recipe.inputs:
			if Stockpile.is_unavailable_story_item(resource):
				satisfied = false
				break

		if not satisfied:
			continue

		for resource in recipe.outputs:
			if Stockpile.is_unavailable_story_item(resource):
				satisfied = false
				break

		if not satisfied:
			continue

		result.append(recipe)
	return result


const WORK_SMELTING := 4.0
const WORK_CRAFTING := 8.0
const WORK_ASSEMBLING := 16.0

const WORK_OPERATING := WORK_SMELTING * 10.0
const WORK_PACKAGES := WORK_CRAFTING * 10.0


func _ready() -> void:
	var recipe: Recipe

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_BRICKS] = recipe

	recipe.display_name = "Bake Bricks"
	recipe.inputs[Stockpile.ItemType.CLAY] = 1
	recipe.outputs[Stockpile.ItemType.BRICKS] = 1
	recipe.work = WORK_SMELTING
	recipe.needs_capabilities.append(Capabilities.FURNACE)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_PLANKS] = recipe

	recipe.display_name = "Saw Planks"
	recipe.inputs[Stockpile.ItemType.LUMBER] = 1
	recipe.outputs[Stockpile.ItemType.PLANKS] = 8
	recipe.work = WORK_CRAFTING
	recipe.needs_capabilities.append(Capabilities.WORKBENCH)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_BRASS] = recipe

	recipe.display_name = "Smelt Brass"
	recipe.inputs[Stockpile.ItemType.RAW_BRASS] = 3
	recipe.outputs[Stockpile.ItemType.BRASS_INGOTS] = 3
	recipe.outputs[Stockpile.ItemType.BATTERY_ACID] = 1
	recipe.work = WORK_SMELTING * 3.0
	recipe.needs_capabilities.append(Capabilities.FURNACE)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_CUPRONICKEL] = recipe

	recipe.display_name = "Smelt Cupronickel"
	recipe.inputs[Stockpile.ItemType.RAW_CUPRONICKEL] = 3
	recipe.outputs[Stockpile.ItemType.CUPRONICKEL_INGOTS] = 3
	recipe.outputs[Stockpile.ItemType.BATTERY_ACID] = 1
	recipe.work = WORK_SMELTING * 3.0
	recipe.needs_capabilities.append(Capabilities.FURNACE)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_MECHANICAL_COMPONENTS] = recipe

	recipe.display_name = "Craft Mechanical Components"
	recipe.inputs[Stockpile.ItemType.BRASS_INGOTS] = 1
	recipe.inputs[Stockpile.ItemType.PLANKS] = 1
	recipe.outputs[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 1
	recipe.work = WORK_CRAFTING
	recipe.needs_capabilities.append(Capabilities.WORKBENCH)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_FLUID_HARDWARE] = recipe

	recipe.display_name = "Manufacture Fluid Hardware"
	recipe.inputs[Stockpile.ItemType.CUPRONICKEL_INGOTS] = 8
	recipe.inputs[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 2
	recipe.outputs[Stockpile.ItemType.FLUID_HARDWARE] = 1
	recipe.work = WORK_PACKAGES
	recipe.needs_capabilities.append(Capabilities.LATHE)
	recipe.needs_capabilities.append(Capabilities.CNC_MILL)
	recipe.needs_capabilities.append(Capabilities.OVERHEAD_CRANE)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_POWER_CELLS] = recipe

	recipe.display_name = "Assemble Power Cell"
	recipe.inputs[Stockpile.ItemType.RAW_TITANIUM] = 3
	recipe.inputs[Stockpile.ItemType.RAW_ELECTRUM] = 1
	recipe.inputs[Stockpile.ItemType.CUPRONICKEL_INGOTS] = 1
	recipe.inputs[Stockpile.ItemType.BATTERY_ACID] = 1
	recipe.outputs[Stockpile.ItemType.POWER_CELLS] = 1
	recipe.work = WORK_ASSEMBLING
	recipe.needs_capabilities.append(Capabilities.ASSEMBLY_STATION)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_ELECTRUM_WIRE] = recipe

	recipe.display_name = "Draw Electrum Wire"
	recipe.inputs[Stockpile.ItemType.RAW_ELECTRUM] = 1
	recipe.outputs[Stockpile.ItemType.ELECTRUM_WIRE] = 1
	recipe.work = WORK_CRAFTING
	recipe.needs_capabilities.append(Capabilities.WIRE_MILL)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_SEMICONDUCTORS] = recipe

	recipe.display_name = "Manufacture Semiconductor Precursors"
	recipe.inputs[Stockpile.ItemType.SAND] = 1
	recipe.inputs[Stockpile.ItemType.EVAPORITES] = 1
	recipe.outputs[Stockpile.ItemType.SEMICONDUCTORS] = 1
	recipe.work = WORK_CRAFTING
	recipe.needs_capabilities.append(Capabilities.CLEANROOM)

	recipe = Recipe.new()
	_recipe_map[RecipeType.OPERATE_REFINERY] = recipe

	recipe.display_name = "Operate Petrochemical Refinery"
	recipe.inputs[Stockpile.ItemType.PETROCHEMICALS] = 2
	recipe.outputs[Stockpile.ItemType.ACRYLIC] = 1
	recipe.outputs[Stockpile.ItemType.PLASTIC] = 1
	recipe.work = WORK_OPERATING
	recipe.needs_capabilities.append(Capabilities.REFINERY)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_INTEGRATED_CIRCUITS] = recipe

	recipe.display_name = "Assemble Integrated Circuits"
	recipe.inputs[Stockpile.ItemType.SEMICONDUCTORS] = 1
	recipe.inputs[Stockpile.ItemType.ELECTRUM_WIRE] = 1
	recipe.inputs[Stockpile.ItemType.CLAY] = 1
	recipe.outputs[Stockpile.ItemType.INTEGRATED_CIRCUITS] = 9
	recipe.work = WORK_ASSEMBLING * 3.0
	recipe.needs_capabilities.append(Capabilities.CLEANROOM)
	recipe.needs_capabilities.append(Capabilities.LITHOGRAPHY)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_ELECTRONIC_COMPONENTS] = recipe

	recipe.display_name = "Craft Electronic Components"
	recipe.inputs[Stockpile.ItemType.INTEGRATED_CIRCUITS] = 1
	recipe.inputs[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 1
	recipe.inputs[Stockpile.ItemType.ELECTRUM_WIRE] = 1
	recipe.inputs[Stockpile.ItemType.EVAPORITES] = 1
	recipe.inputs[Stockpile.ItemType.CUPRONICKEL_INGOTS] = 1
	recipe.inputs[Stockpile.ItemType.PLASTIC] = 1
	recipe.outputs[Stockpile.ItemType.ELECTRONIC_COMPONENTS] = 3
	recipe.work = WORK_CRAFTING * 3.0
	recipe.needs_capabilities.append(Capabilities.LATHE)
	recipe.needs_capabilities.append(Capabilities.CNC_MILL)
	recipe.needs_capabilities.append(Capabilities.SOLDERING_STATION)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_INDUSTRIAL_CONTROLLERS] = recipe

	recipe.display_name = "Manufacture Industrial Computer Modules"
	recipe.inputs[Stockpile.ItemType.INTEGRATED_CIRCUITS] = 6
	recipe.inputs[Stockpile.ItemType.ELECTRUM_WIRE] = 6
	recipe.inputs[Stockpile.ItemType.PLASTIC] = 3
	recipe.outputs[Stockpile.ItemType.INDUSTRIAL_CONTROLLERS] = 1
	recipe.work = WORK_PACKAGES
	recipe.needs_capabilities.append(Capabilities.ASSEMBLY_STATION)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_JELLY_STANDEES] = recipe

	recipe.display_name = "Mold Jelly Standees"
	recipe.inputs[Stockpile.ItemType.ACRYLIC] = 1
	recipe.inputs[Stockpile.ItemType.HOSHIUMIUM] = 1
	recipe.outputs[Stockpile.ItemType.JELLY_STANDEES] = 1
	recipe.work = WORK_SMELTING
	recipe.needs_capabilities.append(Capabilities.INJECTION_MOLDING)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_EVAPORITES] = recipe

	recipe.display_name = "Evaporate Brine"
	recipe.inputs[Stockpile.ItemType.WATER] = 3
	recipe.outputs[Stockpile.ItemType.EVAPORITES] = 1
	recipe.work = WORK_OPERATING
	recipe.needs_capabilities.append(Capabilities.REFINERY)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_JELLY_COFFEE] = recipe

	recipe.display_name = "Brew Jelly Coffee"
	recipe.inputs[Stockpile.ItemType.COFFEE_CHERRIES] = 1
	recipe.inputs[Stockpile.ItemType.WATER] = 1
	recipe.outputs[Stockpile.ItemType.JELLY_COFFEE] = 1
	recipe.work = WORK_CRAFTING
	recipe.needs_capabilities.append(Capabilities.WORKBENCH)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_STEAM_ENGINE] = recipe

	recipe.display_name = "Manufacture Steam Engine"
	recipe.inputs[Stockpile.ItemType.RAW_TITANIUM] = 10000
	recipe.inputs[Stockpile.ItemType.WATER] = 10000
	recipe.inputs[Stockpile.ItemType.FLUID_HARDWARE] = 100
	recipe.inputs[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 100
	recipe.outputs[Stockpile.ItemType.STEAM_ENGINE] = 1
	recipe.work = 120.0
	recipe.needs_capabilities.append(Capabilities.WORKBENCH)
	recipe.needs_capabilities.append(Capabilities.OVERHEAD_CRANE)

	##########################
	### PC related recipes ###
	##########################

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_PC_GLASS] = recipe

	recipe.display_name = "Fabricate Tempered Glass Panel"
	recipe.inputs[Stockpile.ItemType.SAND] = 20
	recipe.outputs[Stockpile.ItemType.PC_GLASS] = 1
	recipe.work = WORK_CRAFTING
	recipe.needs_capabilities.append(Capabilities.FURNACE)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_PC_CASE] = recipe

	recipe.display_name = "Fabricate PC Case"
	recipe.inputs[Stockpile.ItemType.RAW_TITANIUM] = 10
	recipe.outputs[Stockpile.ItemType.PC_CASE] = 1
	recipe.work = WORK_CRAFTING
	recipe.needs_capabilities.append(Capabilities.LATHE)
	recipe.needs_capabilities.append(Capabilities.CNC_MILL)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_PC_FANS] = recipe

	recipe.display_name = "Mold PC Fans"
	recipe.inputs[Stockpile.ItemType.PLASTIC] = 5
	recipe.inputs[Stockpile.ItemType.ELECTRUM_WIRE] = 5
	recipe.inputs[Stockpile.ItemType.ELECTRONIC_COMPONENTS] = 1
	recipe.outputs[Stockpile.ItemType.PC_FANS] = 1
	recipe.work = WORK_CRAFTING
	recipe.needs_capabilities.append(Capabilities.INJECTION_MOLDING)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_PC_POWER_SUPPLY] = recipe

	recipe.display_name = "Assemble PC Power Supply"
	recipe.inputs[Stockpile.ItemType.ELECTRONIC_COMPONENTS] = 5
	recipe.inputs[Stockpile.ItemType.POWER_CELLS] = 2
	recipe.inputs[Stockpile.ItemType.ELECTRUM_WIRE] = 10
	recipe.inputs[Stockpile.ItemType.PC_FANS] = 1
	recipe.outputs[Stockpile.ItemType.PC_POWER_SUPPLY] = 1
	recipe.work = WORK_CRAFTING
	recipe.needs_capabilities.append(Capabilities.SOLDERING_STATION)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_PC_MOTHERBOARD] = recipe

	recipe.display_name = "Assemble PC Motherboard"
	recipe.inputs[Stockpile.ItemType.INTEGRATED_CIRCUITS] = 20
	recipe.inputs[Stockpile.ItemType.ELECTRONIC_COMPONENTS] = 5
	recipe.inputs[Stockpile.ItemType.ELECTRUM_WIRE] = 20
	recipe.inputs[Stockpile.ItemType.PLASTIC] = 5
	recipe.outputs[Stockpile.ItemType.PC_MOTHERBOARD] = 1
	recipe.work = WORK_CRAFTING
	recipe.needs_capabilities.append(Capabilities.SOLDERING_STATION)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_PC_RAM] = recipe

	recipe.display_name = "Fabricate Phase™ RAM"
	recipe.inputs[Stockpile.ItemType.SEMICONDUCTORS] = 16
	recipe.inputs[Stockpile.ItemType.PLASTIC] = 1
	recipe.outputs[Stockpile.ItemType.PC_RAM] = 1
	recipe.work = WORK_CRAFTING
	recipe.needs_capabilities.append(Capabilities.CLEANROOM)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_PC_CPU] = recipe

	recipe.display_name = "Fabricate Phase™ CPU"
	recipe.inputs[Stockpile.ItemType.SEMICONDUCTORS] = 64
	recipe.outputs[Stockpile.ItemType.PC_CPU] = 1
	recipe.work = WORK_CRAFTING
	recipe.needs_capabilities.append(Capabilities.CLEANROOM)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_PC_GPU] = recipe

	recipe.display_name = "Fabricate Phase™ GPU"
	recipe.inputs[Stockpile.ItemType.SEMICONDUCTORS] = 20
	recipe.inputs[Stockpile.ItemType.INTEGRATED_CIRCUITS] = 20
	recipe.inputs[Stockpile.ItemType.ELECTRONIC_COMPONENTS] = 2
	recipe.inputs[Stockpile.ItemType.PC_FANS] = 3
	recipe.outputs[Stockpile.ItemType.PC_GPU] = 1
	recipe.work = WORK_CRAFTING
	recipe.needs_capabilities.append(Capabilities.CLEANROOM)
	recipe.needs_capabilities.append(Capabilities.SOLDERING_STATION)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_PC_AIO_COOLER] = recipe

	recipe.display_name = "Assemble AIO Cooler"
	recipe.inputs[Stockpile.ItemType.FLUID_HARDWARE] = 1
	recipe.inputs[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 3
	recipe.inputs[Stockpile.ItemType.ELECTRONIC_COMPONENTS] = 3
	recipe.inputs[Stockpile.ItemType.WATER] = 100
	recipe.inputs[Stockpile.ItemType.PC_FANS] = 3
	recipe.outputs[Stockpile.ItemType.PC_AIO_COOLER] = 1
	recipe.work = WORK_CRAFTING
	recipe.needs_capabilities.append(Capabilities.ASSEMBLY_STATION)

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_PC] = recipe

	recipe.display_name = "Assemble Personal Computer"
	recipe.inputs[Stockpile.ItemType.PC_GLASS] = 1
	recipe.inputs[Stockpile.ItemType.PC_CASE] = 1
	recipe.inputs[Stockpile.ItemType.PC_FANS] = 2
	recipe.inputs[Stockpile.ItemType.PC_POWER_SUPPLY] = 1
	recipe.inputs[Stockpile.ItemType.PC_MOTHERBOARD] = 1
	recipe.inputs[Stockpile.ItemType.PC_RAM] = 4
	recipe.inputs[Stockpile.ItemType.PC_CPU] = 1
	recipe.inputs[Stockpile.ItemType.PC_GPU] = 1
	recipe.inputs[Stockpile.ItemType.PC_AIO_COOLER] = 1
	recipe.outputs[Stockpile.ItemType.PC_PC] = 1
	recipe.work = WORK_PACKAGES
	recipe.needs_capabilities.append(Capabilities.ASSEMBLY_STATION)
