class_name Challenge


var state: Stockpile.ChallengeState = Stockpile.ChallengeState.LOCKED
var _limit = false


func _init(p_limit = false) -> void:
	_limit = p_limit


func is_limit_reached(produced: int) -> bool:
	return _limit != false and produced >= _limit


func get_limit() -> int:
	return _limit
