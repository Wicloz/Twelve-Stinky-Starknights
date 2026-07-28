extends Node

## Records every PLAYER ACTION with a timestamp and the hex tile it happened on,
## so a playthrough can be replayed against tools/balance_model.py. The model's
## whole premise is that "fun" is the density of player decisions over time, and it
## predicts a timeline of them -- this is the ground truth to check that against.
##
## Actions are recorded from the model classes rather than the UI, so every route
## to an action is caught (placing from the deposit panel and from the hotbar both
## go through CatalogItem.try_place_on, for instance).
##
## The kinds match balance_model.py's action vocabulary exactly:
##   build / demolish / harvest / craft / research / wresearch / upgrade / automate
##
## Every action has a tile, because every Job has a target tile: a craft happens at
## the Workshop, research happens at the building it belongs to, and a Starknight
## has to walk there. q,r are the axial coordinates HexMap/ZaWarudo use, so a log
## can be joined straight onto the map -- which is what makes travel measurable.
##
## Writes user://activity_log.csv (path is printed on startup), flushed after every
## line so a crash or an alt-F4 still leaves a complete log.

const PATH := "user://activity_log.csv"
const HEADER := "seconds,minutes,kind,name,q,r,detail"

var entries: Array[Dictionary] = []

var _start_usec: int = 0
var _file: FileAccess = null


func _ready() -> void:
	# HexTile is a @tool script, so the editor instantiates the autoloads too --
	# without this, opening the project would truncate the last run's log.
	if Engine.is_editor_hint():
		return

	_start_usec = Time.get_ticks_usec()

	_file = FileAccess.open(PATH, FileAccess.WRITE)
	if _file == null:
		push_warning("ActivityLog: cannot write %s (%s)" % [PATH, FileAccess.get_open_error()])
		return

	_file.store_line(HEADER)
	_file.flush()
	print("ActivityLog -> ", ProjectSettings.globalize_path(PATH))


## Seconds since the game started. Cutscenes do not pause the sim, so this is the
## same wall clock the model plans against.
func elapsed() -> float:
	return (Time.get_ticks_usec() - _start_usec) / 1_000_000.0


func record(kind: String, name: String, tile: HexTile, detail: String = "") -> void:
	var seconds := elapsed()

	entries.append({
		"seconds": seconds,
		"kind": kind,
		"name": name,
		"q": tile.q if tile else 0,
		"r": tile.r if tile else 0,
		"tile": tile,
		"detail": detail,
	})

	if _file == null:
		return

	# 0,0 is a real hex, so a tile-less action leaves the columns EMPTY rather than
	# claiming the map origin. (Every action should have one; this is just honest.)
	var where := ("%d,%d" % [tile.q, tile.r]) if tile else ","

	_file.store_line("%.2f,%.3f,%s,%s,%s,%s" % [
		seconds, seconds / 60.0, kind, _escape(name), where, _escape(detail),
	])
	_file.flush()


## Research is one call site but four different decisions in the model's terms, so
## classify it here where the ResearchItem and its building are both in hand. The
## tile is the building's: that is where the research Job is posted.
func record_research(item: ResearchItem, building: Building) -> void:
	var kind := "upgrade"

	if item.display_name == "Automation":
		kind = "automate"
	elif building is Workshop:
		kind = "research"
	elif building is Warehouse:
		kind = "wresearch"

	record(kind, item.display_name, building.tile, building.get_display_name())


func _escape(text: String) -> String:
	# keep the CSV single-line and comma-safe without pulling in a quoting scheme
	return text.replace(",", ";").replace("\n", " ")


## Everything logged so far, as the same "label @ m.m min" lines balance_model.py
## prints for its discovered plan -- handy for eyeballing the two side by side.
func as_plan_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for entry in entries:
		var label: String = entry["name"]
		if entry["detail"] != "":
			label += " (" + entry["detail"] + ")"
		lines.append("%-40s @ %6.1f min   [%s @ %d,%d]" % [
			label, entry["seconds"] / 60.0, entry["kind"], entry["q"], entry["r"],
		])
	return lines
