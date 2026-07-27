class_name ResearchItem


enum State {
	LOCKED,
	AVAILABLE,
	RESEARCHING,
	COMPLETED,
}

var display_name: String
var description: String
var display_effect: String
var texture: Texture2D

var cost: Dictionary[Stockpile.ItemType, int] = {}
var work: float = 60.0

var research_at: Script
var slot: int
var prerequisites: Array[ResearchItem] = []

var on_complete: Callable
var state: State = State.LOCKED


static func format_effect(label: String, factor: float) -> String:
	var factor_str: String
	if is_equal_approx(factor, roundf(factor)):
		factor_str = str(roundi(factor))
	else:
		factor_str = str(factor)

	return "> %s x%s" % [label, factor_str]


func acronym() -> String:
	var words := display_name.split(" ")
	var text := ""

	for word in words:
		text += word[0]

	return text


func tooltip() -> String:
	var text := display_name + "\n"
	var body: Array[String] = []

	if description != "":
		body.append(description)
	if display_effect != "":
		body.append(display_effect)

	if not body.is_empty():
		text += "\n" + "\n".join(body) + "\n"

	for resource in cost:
		text += "\n" + "%s: %d" % [Stockpile.get_display_name(resource), cost[resource]]

	match state:
		ResearchItem.State.LOCKED:
			text += "\n\n" + "Needs: " + _missing_prerequisites()
		ResearchItem.State.RESEARCHING:
			text += "\n\n" + "Being Researched ..."

	return text


func _missing_prerequisites() -> String:
	var names: Array[String] = []

	for prerequisite in prerequisites:
		if prerequisite.state != ResearchItem.State.COMPLETED:
			names.append(prerequisite.display_name)

	return ", ".join(names)
