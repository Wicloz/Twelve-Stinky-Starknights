class_name HexAStar2D
extends AStar2D


var hex_coords_by_id: Dictionary[int, Vector2i] = {}
var ids_by_hex_coord: Dictionary[Vector2i, int] = {}


func _compute_cost(_from_id: int, _to_id: int) -> float:
	return 1.0


func _estimate_cost(from_id: int, to_id: int) -> float:
	var a := hex_coords_by_id[from_id]
	var b := hex_coords_by_id[to_id]
	var dq := a.x - b.x
	var dr := a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2.0


func reset() -> void:
	super.clear()
	hex_coords_by_id.clear()
	ids_by_hex_coord.clear()

func add_tile(idx: int, coord: Vector2i) -> void:
	super.add_point(idx, Vector2.ZERO)
	hex_coords_by_id[idx] = coord
	ids_by_hex_coord[coord] = idx
