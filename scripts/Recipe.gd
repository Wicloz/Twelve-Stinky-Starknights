class_name Recipe


var display_name: String
var inputs: Dictionary[Stockpile.ItemType, int] = {}
var outputs: Dictionary[Stockpile.ItemType, int] = {}
var work: float
var needs_capabilities: Array[Crafting.Capabilities] = []
