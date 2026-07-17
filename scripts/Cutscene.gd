class_name Cutscene


var condition: Callable

var still: Texture2D = null
var video: VideoStream = null
var song: AudioStream = null

var text: String
var typing_speed: float = 20.0
var min_duration: float = 2.0

var on_complete: Callable


func condition_met() -> bool:
    return not condition.is_valid() or condition.call()
