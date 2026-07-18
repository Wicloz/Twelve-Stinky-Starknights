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
	ergonomic_tools.cost[Stockpile.ItemType.PLANKS] = 50
	ergonomic_tools.cost[Stockpile.ItemType.BRASS_INGOTS] = 10
	ergonomic_tools.on_complete = func() -> void:
		Starknight.speed_scale = 1.25

	var powered_exoskeletons := ResearchItem.new()
	research.append(powered_exoskeletons)

	powered_exoskeletons.display_name = "Powered Exoskeletons"
	powered_exoskeletons.description = "Starknights move a further 25% faster."
	powered_exoskeletons.slot = 5
	powered_exoskeletons.prerequisites.append(ergonomic_tools)
	powered_exoskeletons.cost[Stockpile.ItemType.MECHANICAL_COMPONENTS] = 25
	powered_exoskeletons.cost[Stockpile.ItemType.ELECTRUM_WIRE] = 25
	powered_exoskeletons.on_complete = func() -> void:
		Starknight.speed_scale = 1.50

	Research.register_research(self, research)


func get_display_name() -> String:
	return "Phase Warehouse"


func _ready() -> void:
	_define_research()
