extends Node


enum Capabilities {
	FURNACE,
	WORKBENCH,
}

enum RecipeType {
	MAKE_PLANKS,
	MAKE_BRICKS,

	MAKE_BRASS,
	MAKE_MECHANICAL_COMPONENTS,

	MAKE_CUPRONICKEL,
	MAKE_FLUID_HARDWARE,

	MAKE_ELECTRUM_WIRE,
	MAKE_SILICON_BOULE,

	OPERATE_REFINERY,
	MAKE_POWER_CELLS,
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

const WORK_ASSEMBLING := WORK_CRAFTING * 5.0
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

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_POWER_CELLS] = recipe

	recipe.display_name = "Assemble Power Cell"
	recipe.inputs[Stockpile.ItemType.RAW_TITANIUM] = 3
	recipe.inputs[Stockpile.ItemType.RAW_ELECTRUM] = 1
	recipe.inputs[Stockpile.ItemType.CUPRONICKEL_INGOTS] = 1
	recipe.inputs[Stockpile.ItemType.BATTERY_ACID] = 1
	recipe.outputs[Stockpile.ItemType.POWER_CELLS] = 1
	recipe.work = WORK_ASSEMBLING

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_ELECTRUM_WIRE] = recipe

	recipe.display_name = "Draw Electrum Wire"
	recipe.inputs[Stockpile.ItemType.RAW_ELECTRUM] = 1
	recipe.outputs[Stockpile.ItemType.ELECTRUM_WIRE] = 1
	recipe.work = WORK_CRAFTING

	recipe = Recipe.new()
	_recipe_map[RecipeType.MAKE_SILICON_BOULE] = recipe

	recipe.display_name = "Grow Silicon Boule"
	recipe.inputs[Stockpile.ItemType.SAND] = 1
	recipe.outputs[Stockpile.ItemType.SILICON_BOULE] = 1
	recipe.work = WORK_CRAFTING

	recipe = Recipe.new()
	_recipe_map[RecipeType.OPERATE_REFINERY] = recipe

	recipe.display_name = "Operate Petrochemical Refinery"
	recipe.inputs[Stockpile.ItemType.PETROCHEMICALS] = 1
	recipe.outputs[Stockpile.ItemType.ACRYLIC_PLASTIC] = 1
	recipe.work = WORK_OPERATING
