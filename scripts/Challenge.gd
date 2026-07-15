class_name Challenge


var state: Stockpile.ChallengeState = Stockpile.ChallengeState.LOCKED
var _limit = false


func _init(p_limit = false) -> void:
	_limit = p_limit
