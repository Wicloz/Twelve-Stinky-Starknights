extends Node
signal cutscene_started(cutscene: Cutscene)


var _locked_cutscenes: Array[Cutscene] = []
var _cutscene_queue: Array[Cutscene] = []
var _current_cutscene: Cutscene = null


func _ready() -> void:
    _define_cutscenes()
    Stockpile.changed.connect(_on_stockpile_changed)
    _queue_cutscenes()


func _define_cutscenes() -> void:
    var cutscene: Cutscene

    cutscene = Cutscene.new()
    _locked_cutscenes.append(cutscene)

    cutscene.still = preload("res://assets/cutscenes/kevin.png")
    cutscene.text = "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since 1966, when designers at Letraset and James Mosley, the librarian at St Bride Printing Library in London, took a 1914 Cicero translation and scrambled it to make dummy text for Letraset's Body Type sheets. It has survived not only many decades, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised thanks to these sheets and more recently with desktop publishing software like Aldus PageMaker and Microsoft Word including versions of Lorem Ipsum. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
    cutscene.duration = 10.0

    cutscene = Cutscene.new()
    _locked_cutscenes.append(cutscene)

    cutscene.video = preload("res://assets/cutscenes/jungus.ogv")
    cutscene.text = "Jelly: Awawawawawa!"
    cutscene.duration = 10.0


func _queue_cutscenes() -> void:
    for cutscene in _locked_cutscenes.filter(func(cutscene: Cutscene) -> bool:
        return cutscene.conditions_met()
    ):
        _locked_cutscenes.erase(cutscene)
        _cutscene_queue.append(cutscene)


func _on_stockpile_changed() -> void:
    _queue_cutscenes()
    _try_play_next()


func play_next() -> void:
    _try_play_next()


func _try_play_next() -> void:
    if _current_cutscene or _cutscene_queue.is_empty():
        return

    _current_cutscene = _cutscene_queue.pop_front()
    cutscene_started.emit(_current_cutscene)


func finish_current() -> void:
    if not _current_cutscene:
        return

    if _current_cutscene.on_complete.is_valid():
        _current_cutscene.on_complete.call()

    _current_cutscene = null
    _try_play_next()
