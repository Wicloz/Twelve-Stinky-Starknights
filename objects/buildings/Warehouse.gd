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

	var hoverpacks := ResearchItem.new()
	research.append(hoverpacks)

	hoverpacks.display_name = "Unstable Hoverpacks"
	hoverpacks.description = "Starknights move a further 25% faster."
	hoverpacks.slot = 5
	hoverpacks.prerequisites.append(ergonomic_tools)
	hoverpacks.cost[Stockpile.ItemType.FLUID_HARDWARE] = 12
	hoverpacks.cost[Stockpile.ItemType.PETROCHEMICALS] = 120
	hoverpacks.on_complete = func() -> void:
		Starknight.speed_scale = 1.50

	var powered_exoskeletons := ResearchItem.new()
	research.append(powered_exoskeletons)

	powered_exoskeletons.display_name = "Powered Exoskeletons"
	powered_exoskeletons.description = "Starknights move a further 25% faster."
	powered_exoskeletons.slot = 5
	powered_exoskeletons.prerequisites.append(hoverpacks)
	powered_exoskeletons.cost[Stockpile.ItemType.ELECTRONIC_ACTUATORS] = 12
	powered_exoskeletons.cost[Stockpile.ItemType.POWER_CELLS] = 12
	powered_exoskeletons.on_complete = func() -> void:
		Starknight.speed_scale = 1.75

	var guidance_system := ResearchItem.new()
	research.append(guidance_system)

	guidance_system.display_name = "Guidance System"
	guidance_system.description = "Starknights move 2x their base speed."
	guidance_system.slot = 5
	guidance_system.prerequisites.append(powered_exoskeletons)
	guidance_system.cost[Stockpile.ItemType.INTEGRATED_CIRCUITS] = 12
	guidance_system.cost[Stockpile.ItemType.ELECTRONIC_COMPONENTS] = 12
	guidance_system.on_complete = func() -> void:
		Starknight.speed_scale = 2.00

	var coffee_injection := ResearchItem.new()
	research.append(coffee_injection)

	coffee_injection.display_name = "Coffee Injection"
	coffee_injection.description = "Starknights move 3x their base speed."
	coffee_injection.slot = 5
	coffee_injection.prerequisites.append(guidance_system)
	coffee_injection.cost[Stockpile.ItemType.JELLY_COFFEE] = 12000
	coffee_injection.on_complete = func() -> void:
		Starknight.speed_scale = 3.00

	var meka_suit := ResearchItem.new()
	research.append(meka_suit)

	meka_suit.display_name = "MekaSuit Integration"
	meka_suit.description = "Starknights move 4x their base speed."
	meka_suit.slot = 5
	meka_suit.prerequisites.append(coffee_injection)
	meka_suit.cost[Stockpile.ItemType.PLASTIC] = 1200
	meka_suit.cost[Stockpile.ItemType.WHITE_PAINT] = 12
	meka_suit.cost[Stockpile.ItemType.INDUSTRIAL_CONTROLLERS] = 120
	meka_suit.on_complete = func() -> void:
		Starknight.speed_scale = 4.00

	Research.register_research(self, research)


func get_display_name() -> String:
	return "Phase Warehouse"


func _ready() -> void:
	_define_research()
