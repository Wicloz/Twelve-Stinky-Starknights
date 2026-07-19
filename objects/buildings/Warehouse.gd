class_name Warehouse
extends Building


func _define_research() -> void:
	if not Research.can_register(self):
		return
	var research: Array[ResearchItem] = []

	var ergonomic_tools := ResearchItem.new()
	research.append(ergonomic_tools)

	ergonomic_tools.display_name = "Ergonomic Tools"
	ergonomic_tools.description = "Starknights move 25% faster."
	ergonomic_tools.slot = 5
	ergonomic_tools.cost[Stockpile.ItemType.PLANKS] = 120
	ergonomic_tools.cost[Stockpile.ItemType.BRASS_INGOTS] = 120
	ergonomic_tools.on_complete = func() -> void:
		Starknight.speed_scale = 1.25

	var powered_exoskeletons := ResearchItem.new()
	research.append(powered_exoskeletons)

	powered_exoskeletons.display_name = "Powered Exoskeletons"
	powered_exoskeletons.description = "Starknights move a further 25% faster."
	powered_exoskeletons.slot = 5
	powered_exoskeletons.prerequisites.append(ergonomic_tools)
	powered_exoskeletons.cost[Stockpile.ItemType.ELECTRONIC_ACTUATORS] = 12
	powered_exoskeletons.cost[Stockpile.ItemType.POWER_CELLS] = 12
	powered_exoskeletons.on_complete = func() -> void:
		Starknight.speed_scale = 1.50

	var coffee_injection := ResearchItem.new()
	research.append(coffee_injection)

	coffee_injection.display_name = "Coffee Injection"
	coffee_injection.description = "Starknights move 3x their base speed."
	coffee_injection.slot = 5
	coffee_injection.prerequisites.append(powered_exoskeletons)
	coffee_injection.cost[Stockpile.ItemType.JELLY_COFFEE] = 12000
	coffee_injection.on_complete = func() -> void:
		Starknight.speed_scale = 3.00

	Research.register_research(self, research)


func get_display_name() -> String:
	return "Phase Warehouse"


func _ready() -> void:
	_define_research()
