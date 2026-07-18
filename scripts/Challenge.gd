class_name Challenge


var state: Stockpile.ChallengeState = Stockpile.ChallengeState.LOCKED
var _limit = false
var _shown = true


func _init(p_limit = false, p_shown = true) -> void:
	_limit = p_limit
	_shown = p_shown


func is_limit_reached(produced: int) -> bool:
	return _limit is int and produced >= _limit


func get_limit():
	return _limit


func is_shown() -> bool:
	return _shown
