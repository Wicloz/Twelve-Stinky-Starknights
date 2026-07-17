class_name ResearchItem


enum State {
	LOCKED,
	AVAILABLE,
	RESEARCHING,
	COMPLETED,
}

var display_name: String
var description: String
var texture: Texture2D

var cost: Dictionary[Stockpile.ItemType, int] = {}
var work: float = 60.0

var research_at: Script
var slot: int
var prerequisites: Array[ResearchItem] = []

var on_complete: Callable
var state: State = State.LOCKED


func acronym() -> String:
	var words := display_name.split(" ")
	var text := ""

	for word in words:
		text += word[0]

	return text


func tooltip() -> String:
	var text := display_name + "\n"

	if description != "":
		text += "\n" + description + "\n"

	for resource in cost:
		text += "\n%s: %d" % [Stockpile.get_display_name(resource), cost[resource]]

	match state:
		ResearchItem.State.LOCKED:
			text += "\n\nNeeds: " + _missing_prerequisites()
		ResearchItem.State.RESEARCHING:
			text += "\n\nBeing researched."

	return text


func _missing_prerequisites() -> String:
	var names: Array[String] = []

	for prerequisite in prerequisites:
		if prerequisite.state != ResearchItem.State.COMPLETED:
			names.append(prerequisite.display_name)

	return ", ".join(names)
