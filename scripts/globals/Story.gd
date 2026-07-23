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
    pass

    ############################
    ### opening and tutorial ###
    ############################

    var opening_sakana := Cutscene.new()
    _locked_cutscenes.append(opening_sakana)

    opening_sakana.after = []
    opening_sakana.still = preload("res://assets/cutscenes/kevin.png")
    opening_sakana.text = say(SAKANA, "Sakana", "We are debuting a new VTuber called Jeffrey Moshimoshi or something. Whatever man. We sent our twelve stinkiest \"workers\" (thats you) to this \"unclaimed\" planet in the Gliese 67 system. [i]clears throat[/i] \"Your job is to support Jelly? Hoshiumi? during her VTuber activities using the local resources. You have been provided with an adaptive blueprint package and a workshop for optimal in-situ resource utilization ...\" What is this speech man I'm not doing this. Anyway outsourcing her support to you guys is a great way to save some money. Just make sure to build that [u]warehouse[/u] as soon as possible.")

    var opening_tutorial := Cutscene.new()
    _locked_cutscenes.append(opening_tutorial)

    opening_tutorial.after = [opening_sakana]
    opening_tutorial.still = preload("res://assets/cutscenes/aiko.jpg")
    opening_tutorial.text = say(AIKO, "Aiko", "Click on a deposit tile and enable harvesting to have a Starknight work it. Use the [u]workshop[/u] to manually craft small amounts of items, you will need 10 clay bricks and 10 mechanical components to get started. Construct buildings from the picker at the bottom, then click on them to access their upgrades. This will significantly speed up extraction and production. Number go up!")

    ##############################
    ### warehouse intermission ###
    ##############################

    var warehouse_intermission := Cutscene.new()
    _locked_cutscenes.append(warehouse_intermission)

    warehouse_intermission.after = [opening_sakana]
    warehouse_intermission.condition = func() -> bool:
        return Catalog.has_finished_construction(Warehouse)
    warehouse_intermission.still = preload("res://assets/cutscenes/kevin.png")
    warehouse_intermission.text = say(SAKANA, "Sakana", "People think a warehouse is just... a big box full of smaller boxes. Wrong. Amateur mindset. A warehouse is civilization. Every civilization invents roads, agriculture, taxes... and eventually someone has to figure out where to put thirty-seven pallets of Pippa socks without blocking the forklift. That someone is me. See these aisles? Beautiful. Straight. Infinite. Every rack has a purpose. Every pallet has an address. Every crate knows where it belongs. I did that. With this, Phase Connect shipping has expanded to yet another planet. And I have yet another warehouse to organize.")

    #####################################
    ### optional guides for slowpokes ###
    #####################################

    var pitmine_tutorial := Cutscene.new()
    _locked_cutscenes.append(pitmine_tutorial)

    pitmine_tutorial.after = [opening_tutorial]
    pitmine_tutorial.condition = func() -> bool:
        return Catalog.has_finished_construction(FluidHardwareFactory) and not Catalog.has_finished_construction(Pitmine)
    pitmine_tutorial.still = preload("res://assets/cutscenes/aiko.jpg")
    pitmine_tutorial.text = say(AIKO, "Aiko", "Build a pitmine on top of a metalloid or sediment deposit to significantly speed up extraction.")

    ##############################
    ### debut and standee task ###
    ##############################

    var debut_intro := Cutscene.new()
    _locked_cutscenes.append(debut_intro)

    debut_intro.after = [opening_tutorial]
    debut_intro.condition = func() -> bool:
        return Catalog.has_finished_construction(MechanicalComponentFactory)
    debut_intro.still = preload("res://assets/cutscenes/kevin.png")
    debut_intro.text = say(SAKANA, "Sakana", "Wow it looks like you guys have been busy up there. Anyway its time for Jerome's debut now.")

    var jelly_debut := Cutscene.new()
    _locked_cutscenes.append(jelly_debut)

    jelly_debut.after = [debut_intro]
    jelly_debut.video = preload("res://assets/cutscenes/jelly_debut.ogv")
    jelly_debut.song = preload("res://assets/music/jelly/Luminary.ogg")
    jelly_debut.text = say(JELLY, "Jelly", "[wave amp=40 freq=4]Awawawawawawawawa![/wave]")
    jelly_debut.min_duration = 1471.0 / 20.0

    var standee_intro := Cutscene.new()
    _locked_cutscenes.append(standee_intro)

    standee_intro.after = [jelly_debut]
    standee_intro.still = preload("res://assets/cutscenes/kevin.png")
    standee_intro.text = say(SAKANA, "Sakana", "Now that that's over, its time for you to start producing merchandise. I'm not paying you nothing for nothing. Best get started on those standees, every VTuber needs standees.")
    standee_intro.on_complete = func() -> void:
        Stockpile.start_challenge(Stockpile.ItemType.JELLY_STANDEES)

    var merch_tutorial := Cutscene.new()
    _locked_cutscenes.append(merch_tutorial)

    merch_tutorial.after = [standee_intro]
    merch_tutorial.still = preload("res://assets/cutscenes/aiko.jpg")
    merch_tutorial.text = say(AIKO, "Aiko", "Merchandise targets are listed below. You will need a [u]warehouse[/u] to store and ship this merchandise. Build one if you have not already.")

    ######################################
    ### standee into jelly coffee task ###
    ######################################

    var standee_crafted := Cutscene.new()
    _locked_cutscenes.append(standee_crafted)

    standee_crafted.after = [merch_tutorial]
    standee_crafted.condition = func() -> bool:
        return Stockpile.is_seen(Stockpile.ItemType.JELLY_STANDEES)
    standee_crafted.still = preload("res://assets/cutscenes/kevin.png")
    standee_crafted.text = say(SAKANA, "Sakana", "Great start! Now do it again. Just make as many as you can man.") + say(SAKANA, "Sakana", "What is Phase Connect's most important product? Trick question, its coffee of course. We're a coffee company. Kelly wants sumatra beans, get back to work.")
    standee_crafted.on_complete = func() -> void:
        Stockpile.start_challenge(Stockpile.ItemType.JELLY_COFFEE)

    var coffee_crafted := Cutscene.new()
    _locked_cutscenes.append(coffee_crafted)

    coffee_crafted.after = [standee_crafted]
    coffee_crafted.condition = func() -> bool:
        return Stockpile.is_seen(Stockpile.ItemType.JELLY_COFFEE)
    coffee_crafted.video = preload("res://assets/cutscenes/jelly_coffee.ogv")
    coffee_crafted.text = say(JELLY, "Jelly", "[wave amp=40 freq=4]Awawawawawawawawa![/wave]")
    coffee_crafted.min_duration = 1728.0 / 10.0

    ####################
    ### steam engine ###
    ####################

    var steam_engine_start := Cutscene.new()
    _locked_cutscenes.append(steam_engine_start)

    steam_engine_start.after = [jelly_debut]
    steam_engine_start.condition = func() -> bool:
        return Workshop.has_capability(Crafting.Capabilities.OVERHEAD_CRANE)
    steam_engine_start.video = preload("res://assets/cutscenes/jelly_big_brother.ogv")
    steam_engine_start.text = say(JELLY, "Jelly", "Starknights! Starknights! I want a steam engine make me a steam engine.")
    steam_engine_start.on_complete = func() -> void:
        Stockpile.start_challenge(Stockpile.ItemType.STEAM_ENGINE)

    var steam_engine_done := Cutscene.new()
    _locked_cutscenes.append(steam_engine_done)

    steam_engine_done.condition = func() -> bool:
        return Stockpile.is_challenge_completed(Stockpile.ItemType.STEAM_ENGINE)
    steam_engine_done.video = preload("res://assets/cutscenes/jelly_choo_choo.ogv")
    steam_engine_done.text = say(JELLY, "Jelly", "[wave amp=40 freq=4]Choo! Choo![/wave]") + say(JELLY, "Jelly", "[wave amp=40 freq=4]Choo! Choo![/wave]") + say(JELLY, "Jelly", "[wave amp=40 freq=4]Choo! Choo![/wave]")
    steam_engine_done.min_duration = 349.0 / 60.0 + 113.0 / 30.0 + 59.0 / 4.0

    ###################
    ### white paint ###
    ###################

    var white_paint_start := Cutscene.new()
    _locked_cutscenes.append(white_paint_start)

    white_paint_start.after = [jelly_debut]
    white_paint_start.condition = func() -> bool:
        return Stockpile.get_cumulative(Stockpile.ItemType.PLASTIC) >= 10000
    white_paint_start.video = preload("res://assets/cutscenes/jelly_big_brother.ogv")
    white_paint_start.text = say(JELLY, "Jelly", "I'm all out of stream ideas man... Surely, surely, nobody would literally watch paint dry with me... I'm going to do a paint drying stream, Starknights, get me enough white paint for six hours.")
    white_paint_start.on_complete = func() -> void:
        Stockpile.start_challenge(Stockpile.ItemType.WHITE_PAINT)

    var white_paint_done := Cutscene.new()
    _locked_cutscenes.append(white_paint_done)

    white_paint_done.condition = func() -> bool:
        return Stockpile.is_challenge_completed(Stockpile.ItemType.WHITE_PAINT)
    white_paint_done.video = preload("res://assets/cutscenes/white_paint_dries.ogv")
    white_paint_done.text = say(JELLY, "Jelly", "...")
    white_paint_done.min_duration = 1800.0 / 10.0

    #############
    ### PC PC ###
    #############

    var pc_pc_image_1 := Cutscene.new()
    _locked_cutscenes.append(pc_pc_image_1)

    pc_pc_image_1.after = [jelly_debut]
    pc_pc_image_1.condition = func() -> bool:
        return Stockpile.is_seen(Stockpile.ItemType.INDUSTRIAL_CONTROLLERS)
    pc_pc_image_1.still = preload("res://assets/cutscenes/jelly_pc_1.jpg")
    pc_pc_image_1.text = say(JELLY, "Jelly", "[i]sobs[/i]")
    pc_pc_image_1.min_duration = 5.0

    var pc_pc_image_2 := Cutscene.new()
    _locked_cutscenes.append(pc_pc_image_2)

    pc_pc_image_2.after = [pc_pc_image_1]
    pc_pc_image_2.still = preload("res://assets/cutscenes/jelly_pc_2.jpg")
    pc_pc_image_2.text = say(JELLY, "Jelly", "[i]sobs[/i]")
    pc_pc_image_2.min_duration = 5.0

    var pc_pc_intro := Cutscene.new()
    _locked_cutscenes.append(pc_pc_intro)

    pc_pc_intro.after = [pc_pc_image_2]
    pc_pc_intro.video = preload("res://assets/cutscenes/jelly_big_brother.ogv")
    pc_pc_intro.text = say(JELLY, "Jelly", "Waaaaah waaaaah I tried cleaning my PC and it freaking exploded! I'm going to ask Sakana to buy me a new PC man.")

    var pc_pc_sakana := Cutscene.new()
    _locked_cutscenes.append(pc_pc_sakana)

    pc_pc_sakana.after = [pc_pc_intro]
    pc_pc_sakana.still = preload("res://assets/cutscenes/kevin.png")
    pc_pc_sakana.text = say(SAKANA, "Sakana", "Yeah I'm not buying her a new PC man, thats what you guys are for. It can't be that hard man its just Lego for adults.")
    pc_pc_sakana.on_complete = func() -> void:
        Stockpile.start_challenge(Stockpile.ItemType.PC_RAM)
        Stockpile.start_challenge(Stockpile.ItemType.PC_CPU)
        Stockpile.start_challenge(Stockpile.ItemType.PC_GPU)
        Stockpile.start_challenge(Stockpile.ItemType.PC_MOTHERBOARD)
        Stockpile.start_challenge(Stockpile.ItemType.PC_POWER_SUPPLY)
        Stockpile.start_challenge(Stockpile.ItemType.PC_GLASS)
        Stockpile.start_challenge(Stockpile.ItemType.PC_CASE)
        Stockpile.start_challenge(Stockpile.ItemType.PC_FANS)
        Stockpile.start_challenge(Stockpile.ItemType.PC_AIO_COOLER)
        Stockpile.start_challenge(Stockpile.ItemType.PC_PC)


const SAKANA := "#8682c6"
const JELLY := "#23deff"
const AIKO := "#ffffff"


static func say(color: String, speaker: String, line: String) -> String:
    return "[color=%s][b]%s:[/b] %s[/color]\n\n" % [color, speaker, line]


func _queue_cutscenes() -> void:
    for cutscene in _locked_cutscenes.duplicate():
        if _can_queue_cutscene(cutscene):
            _locked_cutscenes.erase(cutscene)
            _cutscene_queue.append(cutscene)


func _can_queue_cutscene(cutscene: Cutscene) -> bool:
    if not cutscene.condition_met():
        return false

    for after_cutscene in cutscene.after:
        if after_cutscene in _locked_cutscenes:
            return false

    return true


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
