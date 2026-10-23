class_name KingAugmentEffect
extends AugmentEffect

func on_physics_tick(game: Node, player_id: int, _delta: float) -> void:
	var rect: Rect2 = AlkkagiBoard.BOARD_RECT
	for piece in game.get_pieces():
		if piece.owner_id != player_id or piece.transformation == "KING":
			continue
		var enemy_edge_reached: bool = piece.position.y > rect.end.y - 28.0 if player_id == 1 else piece.position.y < rect.position.y + 28.0
		if enemy_edge_reached:
			piece.reached_enemy_end = true
		var home_returned: bool = piece.position.y < rect.position.y + rect.size.y * 0.34 if player_id == 1 else piece.position.y > rect.position.y + rect.size.y * 0.66
		if piece.reached_enemy_end and home_returned:
			piece.transform_as("KING")
			game.board.add_effect_line(piece.position + Vector2(-24, 0), piece.position + Vector2(24, 0), Color("ffd45e"), 1.0, 5.0)
