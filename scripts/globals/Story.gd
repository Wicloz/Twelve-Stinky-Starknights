extends Node
signal cutscene_started(cutscene: Cutscene)


var _locked_cutscenes: Array[Cutscene] = []
var _cutscene_queue: Array[Cutscene] = []
var _current_cutscene: Cutscene = null
var _cooldown: bool = false

const DELAY_BETWEEN_CUTSCENES := 3.0
const CONDITION_POLL_INTERVAL := 1.0

var _poll_timer := Timer.new()


func _ready() -> void:
    _define_cutscenes()

    _poll_timer.wait_time = CONDITION_POLL_INTERVAL
    _poll_timer.timeout.connect(_on_poll)
    add_child(_poll_timer)
    _poll_timer.start()

    _queue_cutscenes()


func _define_cutscenes() -> void:
    var cutscene: Cutscene

    cutscene = Cutscene.new()
    _locked_cutscenes.append(cutscene)

    cutscene.still = preload("res://assets/cutscenes/kevin.png")
    cutscene.text = say(SAKANA, "Sakana", "We are debuting a new VTuber called Jeffrey Moshimoshi or something. Whatever man. We sent our twelve stinkiest \"workers\" (thats you) to this \"unclaimed\" planet in the Gliese 67 system. [i]clears throat[/i] \"Your job is to support Jelly? Hoshiumi? during her VTuber activities using the local resources. You have been provided with an adaptive blueprint package and a workshop for optimal in-situ resource utilization ...\" What is this speech man I'm not doing this. Anyway outsourcing her support to you guys is a great way to save some money. Just make sure to build that [u]warehouse[/u] as soon as possible.")

    cutscene = Cutscene.new()
    _locked_cutscenes.append(cutscene)

    cutscene.still = preload("res://assets/cutscenes/aiko.jpg")
    cutscene.text = say(AIKO, "Aiko", "Click on a deposit tile and enable harvesting to have a Starknight work it. Use the [u]workshop[/u] to manually craft small amounts of items. Construct buildings from the picker at the bottom to speed up extraction and production. You will need 10 clay bricks and 10 lumber to get started. You have some time to build up your own infrastructure before the debut.")

    cutscene = Cutscene.new()
    _locked_cutscenes.append(cutscene)

    cutscene.condition = func() -> bool:
        return Catalog.has_finished_construction(MechanicalComponentFactory)
    cutscene.still = preload("res://assets/cutscenes/kevin.png")
    cutscene.text = say(SAKANA, "Sakana", "Wow it looks like you guys have been busy there. Anyway its time for Jerome's debut now.")

    cutscene = Cutscene.new()
    _locked_cutscenes.append(cutscene)

    cutscene.condition = func() -> bool:
        return Catalog.has_finished_construction(MechanicalComponentFactory)
    cutscene.video = preload("res://assets/cutscenes/jelly_debut.ogv")
    cutscene.song = preload("res://assets/music/jelly/Luminary.ogg")
    cutscene.text = say(JELLY, "Jelly", "[wave amp=40 freq=4]Awawawawawawawawa![/wave]")
    cutscene.min_duration = 73.0

    cutscene = Cutscene.new()
    _locked_cutscenes.append(cutscene)

    cutscene.condition = func() -> bool:
        return Catalog.has_finished_construction(MechanicalComponentFactory)
    cutscene.still = preload("res://assets/cutscenes/kevin.png")
    cutscene.text = say(SAKANA, "Sakana", "Now that that's over, its time for you to start producing merchandise. I'm not paying you nothing for nothing. Best get started on those standees, every VTuber needs standees.")
    cutscene.on_complete = func() -> void:
        Stockpile.start_challenge(Stockpile.ItemType.JELLY_STANDEES)

    cutscene = Cutscene.new()
    _locked_cutscenes.append(cutscene)

    cutscene.condition = func() -> bool:
        return Catalog.has_finished_construction(MechanicalComponentFactory)
    cutscene.still = preload("res://assets/cutscenes/aiko.jpg")
    cutscene.text = say(AIKO, "Aiko", "Merchandise targets are listed below. You will need a [u]warehouse[/u] to store and ship this merchandise. Build one if you have not already.")


const SAKANA := "#8682c6"
const JELLY := "#23deff"
const AIKO := "#ffffff"


static func say(color: String, speaker: String, line: String) -> String:
    return "[color=%s][b]%s:[/b] %s[/color]" % [color, speaker, line]


func _queue_cutscenes() -> void:
    for cutscene in _locked_cutscenes.filter(func(cutscene: Cutscene) -> bool:
        return cutscene.condition_met()
    ):
        _locked_cutscenes.erase(cutscene)
        _cutscene_queue.append(cutscene)


func _on_poll() -> void:
    _queue_cutscenes()
    _try_play_next()


func play_next() -> void:
    _try_play_next()


func _try_play_next() -> void:
    if _current_cutscene or _cooldown or _cutscene_queue.is_empty():
        return

    _cooldown = true
    await get_tree().create_timer(DELAY_BETWEEN_CUTSCENES).timeout
    _cooldown = false

    _current_cutscene = _cutscene_queue.pop_front()
    cutscene_started.emit(_current_cutscene)


func finish_current() -> void:
    if not _current_cutscene:
        return

    if _current_cutscene.on_complete.is_valid():
        _current_cutscene.on_complete.call()

    _current_cutscene = null
    _try_play_next()
