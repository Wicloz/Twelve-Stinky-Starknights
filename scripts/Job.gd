class_name Job


var priority: int
var duration: float
var target: HexTile
var on_complete: Callable
var on_cancel: Callable

var _abort_handler: Callable


func register_abort_handler(handler: Callable) -> void:
    _abort_handler = handler


func abort() -> void:
    _abort_handler.call()
