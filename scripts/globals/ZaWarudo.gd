extends Node


const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]

var astar := HexAStar2D.new()
var tiles: Dictionary[Vector2i, HexTile] = {}


func build(new_tiles: Dictionary[Vector2i, HexTile]) -> void:
	astar.reset()
	tiles = new_tiles

	var next_id: int = 0
	for coord in tiles:
		astar.add_tile(next_id, coord)
		astar.set_point_disabled(next_id, not tiles[coord].walkable)
		next_id += 1

	for coord in tiles:
		for offset in NEIGHBOR_OFFSETS:
			var neighbor := coord + offset
			if not tiles.has(neighbor):
				continue
			var from_id := astar.ids_by_hex_coord[coord]
			var to_id := astar.ids_by_hex_coord[neighbor]
			astar.connect_points(from_id, to_id, true)

	_cache_spacing()


func find_path(from: Vector2i, to: Vector2i) -> Array[HexTile]:
	if not astar.ids_by_hex_coord.has(from) or not astar.ids_by_hex_coord.has(to):
		return []

	var id_path := astar.get_id_path(astar.ids_by_hex_coord[from], astar.ids_by_hex_coord[to])
	var path: Array[HexTile] = []
	for id in id_path:
		path.append(tiles[astar.hex_coords_by_id[id]])

	if not path.is_empty():
		path.remove_at(0)
	return path


func walkable_neighbors(coord: Vector2i) -> Array[HexTile]:
	var neighbors: Array[HexTile] = []
	for offset in NEIGHBOR_OFFSETS:
		var tile: HexTile = tiles.get(coord + offset)
		if tile and tile.walkable:
			neighbors.append(tile)
	return neighbors


var _spacing := Vector2.ZERO


func _cache_spacing() -> void:
	var q_ref: HexTile = tiles.get(Vector2i(1, 0))
	var r_ref: HexTile = tiles.get(Vector2i(0, 1))
	if q_ref and r_ref:
		_spacing = Vector2(q_ref.position.x, r_ref.position.y)


func world_to_axial(pos: Vector2) -> Vector2i:
	var r_frac := pos.y / _spacing.y
	var q_frac := pos.x / _spacing.x - r_frac * 0.5
	var s_frac := -q_frac - r_frac

	var q := roundf(q_frac)
	var r := roundf(r_frac)
	var s := roundf(s_frac)

	var q_diff := absf(q - q_frac)
	var r_diff := absf(r - r_frac)
	var s_diff := absf(s - s_frac)

	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s

	return Vector2i(int(q), int(r))
