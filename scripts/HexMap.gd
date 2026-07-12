extends Node2D


func _ready() -> void:
	var tiles: Dictionary[Vector2i, HexTile] = {}
	for child in get_children():
		if child is HexTile:
			tiles[Vector2i(child.q, child.r)] = child

	ZaWarudo.build(tiles)
