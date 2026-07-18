class_name SumatraCoffeeFarm
extends ExtractionBuilding


func get_display_name() -> String:
	return "Sumatra Coffee Farm"


func _determine_harvest() -> void:
	_will_harvest[Stockpile.ItemType.COFFEE_CHERRIES] = _get_yield_scale()
