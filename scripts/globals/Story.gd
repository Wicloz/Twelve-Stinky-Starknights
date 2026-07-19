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

    ############################
    ### opening and tutorial ###
    ############################

    cutscene = Cutscene.new()
    _locked_cutscenes.append(cutscene)

    cutscene.still = preload("res://assets/cutscenes/kevin.png")
    cutscene.text = say(SAKANA, "Sakana", "We are debuting a new VTuber called Jeffrey Moshimoshi or something. Whatever man. We sent our twelve stinkiest \"workers\" (thats you) to this \"unclaimed\" planet in the Gliese 67 system. [i]clears throat[/i] \"Your job is to support Jelly? Hoshiumi? during her VTuber activities using the local resources. You have been provided with an adaptive blueprint package and a workshop for optimal in-situ resource utilization ...\" What is this speech man I'm not doing this. Anyway outsourcing her support to you guys is a great way to save some money. Just make sure to build that [u]warehouse[/u] as soon as possible.")

    cutscene = Cutscene.new()
    _locked_cutscenes.append(cutscene)

    cutscene.still = preload("res://assets/cutscenes/aiko.jpg")
    cutscene.text = say(AIKO, "Aiko", "Click on a deposit tile and enable harvesting to have a Starknight work it. Use the [u]workshop[/u] to manually craft small amounts of items, you will need 10 clay bricks and 10 mechanical components to get started. Construct buildings from the picker at the bottom to speed up extraction and production. This menu will be hidden if you have a building or deposit selected. Buildings can also be upgraded after selecting them. Buildings only show up after you have discovered all of their construction materials, so make sure to explore everything you can.")

    ##############################
    ### warehouse intermission ###
    ##############################

    cutscene = Cutscene.new()
    _locked_cutscenes.append(cutscene)

    cutscene.condition = func() -> bool:
        return Catalog.has_finished_construction(Warehouse)
    cutscene.still = preload("res://assets/cutscenes/kevin.png")
    cutscene.text = say(SAKANA, "Sakana", "People think a warehouse is just... a big box full of smaller boxes. Wrong. Amateur mindset. A warehouse is civilization. Every civilization invents roads, agriculture, taxes... and eventually someone has to figure out where to put thirty-seven pallets of Pippa socks without blocking the forklift. That someone is me. See these aisles? Beautiful. Straight. Infinite. Every rack has a purpose. Every pallet has an address. Every crate knows where it belongs. I did that. With this, Phase Connect shipping has expanded to yet another planet. And I have yet another warehouse to organize.")

    ##############################
    ### debut and standee task ###
    ##############################

    cutscene = Cutscene.new()
    _locked_cutscenes.append(cutscene)

    cutscene.condition = func() -> bool:
        return Catalog.has_finished_construction(MechanicalComponentFactory)
    cutscene.still = preload("res://assets/cutscenes/kevin.png")
    cutscene.text = say(SAKANA, "Sakana", "Wow it looks like you guys have been busy up there. Anyway its time for Jerome's debut now.")

    cutscene = Cutscene.new()
    _locked_cutscenes.append(cutscene)

    cutscene.condition = func() -> bool:
        return Catalog.has_finished_construction(MechanicalComponentFactory)
    cutscene.video = preload("res://assets/cutscenes/jelly_debut.ogv")
    cutscene.song = preload("res://assets/music/jelly/Luminary.ogg")
    cutscene.text = say(JELLY, "Jelly", "[wave amp=40 freq=4]Awawawawawawawawa![/wave]")
    cutscene.min_duration = 73.55

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

    ######################################
    ### standee into jelly coffee task ###
    ######################################

    cutscene = Cutscene.new()
    _locked_cutscenes.append(cutscene)

    cutscene.condition = func() -> bool:
        return Stockpile.is_seen(Stockpile.ItemType.JELLY_STANDEES) and Catalog.has_finished_construction(Warehouse)
    cutscene.still = preload("res://assets/cutscenes/kevin.png")
    cutscene.text = say(SAKANA, "Sakana", "Great start! Now do it again. Just make as many as you can man.") + say(SAKANA, "Sakana", "What is the most important product of Phase Connect? Trick question, its coffee of course. We're a coffee company. Jelly wants sumatra beans, get back to work.")
    cutscene.on_complete = func() -> void:
        Stockpile.start_challenge(Stockpile.ItemType.JELLY_COFFEE)

    ##############################
    ### steam engine choo choo ###
    ##############################

    cutscene = Cutscene.new()
    _locked_cutscenes.append(cutscene)

    cutscene.condition = func() -> bool:
        return Workshop.has_capability(Crafting.Capabilities.OVERHEAD_CRANE)
    cutscene.still = preload("res://assets/cutscenes/kevin.png")
    cutscene.text = say(SAKANA, "Sakana", "Yeah so Jelly needs a steam engine. Don't ask me I don't now either, just get her a steam engine man.")
    cutscene.on_complete = func() -> void:
        Stockpile.start_challenge(Stockpile.ItemType.STEAM_ENGINE)

    cutscene = Cutscene.new()
    _locked_cutscenes.append(cutscene)

    cutscene.condition = func() -> bool:
        return Stockpile.is_challenge_completed(Stockpile.ItemType.STEAM_ENGINE)
    cutscene.video = preload("res://assets/cutscenes/jelly_choo_choo.ogv")
    cutscene.text = say(JELLY, "Jelly", "[wave amp=40 freq=4]Choo! Choo![/wave]") + say(JELLY, "Jelly", "[wave amp=40 freq=4]Choo! Choo![/wave]") + say(JELLY, "Jelly", "[wave amp=40 freq=4]Choo! Choo![/wave]")
    cutscene.min_duration = 5.816666666666666 + 3.7666666666666666 + 14.75


const SAKANA := "#8682c6"
const JELLY := "#23deff"
const AIKO := "#ffffff"


static func say(color: String, speaker: String, line: String) -> String:
    return "[color=%s][b]%s:[/b] %s[/color]\n\n" % [color, speaker, line]


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
