class_name Cutscene


var conditions: Dictionary[Stockpile.ItemType, int] = {}

var still: Texture2D = null
var video: VideoStream = null
var text: String
var typing_speed: float = 20.0
var min_duration: float = 2.0

var on_complete: Callable


func conditions_met() -> bool:
    for item_type in conditions:
        if Stockpile.get_amount(item_type) < conditions[item_type]:
            return false
    return true
