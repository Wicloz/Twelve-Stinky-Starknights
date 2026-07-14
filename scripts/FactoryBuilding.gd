class_name FactoryBuilding
extends Building


@export var recipe: Crafting.RecipeType
var _recipe: Recipe


func _ready() -> void:
    _recipe = Crafting.get_recipe(recipe)
