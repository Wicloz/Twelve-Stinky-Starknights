class_name Cutscene


var conditions: Dictionary[Stockpile.ItemType, int] = {}

var still: Texture2D = null
var video: VideoStream = null
var text: String
var duration: float

var on_complete: Callable


func conditions_met() -> bool:
    for item_type in conditions:
        if Stockpile.get_amount(item_type) < conditions[item_type]:
            return false
    return true
