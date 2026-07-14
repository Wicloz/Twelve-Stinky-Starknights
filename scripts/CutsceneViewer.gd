extends Control


@export var aspect := 16.0 / 9.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		custom_minimum_size.y = size.x / aspect
		custom_maximum_size.y = size.x / aspect
