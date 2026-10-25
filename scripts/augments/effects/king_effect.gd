class_name KingAugmentEffect
extends AugmentEffect

func on_physics_tick(game: Node, player_id: int, _delta: float) -> void:
	var rect: Rect2 = AlkkagiBoard.BOARD_RECT
	for piece: AlkkagiPiece in game.get_pieces():
		if piece.owner_id != player_id or piece.transformation == "KING":
			continue
		var enemy_edge_reached: bool = piece.position.y > rect.end.y - 28.0 if player_id == 1 else piece.position.y < rect.position.y + 28.0
		if enemy_edge_reached:
			piece.reached_enemy_end = true
		var home_returned: bool = piece.position.y < rect.position.y + rect.size.y * 0.34 if player_id == 1 else piece.position.y > rect.position.y + rect.size.y * 0.66
		if piece.reached_enemy_end and home_returned:
			piece.king_size_multiplier = float(definition.values.get("size_multiplier", 1.5))
			piece.king_mass_multiplier = float(definition.values.get("mass_multiplier", 2.0))
			piece.transform_as("KING")
			game.animate_projectile(piece.position - Vector2(30, 0), piece.position + Vector2(30, 0), Color("ffd45e"), 12.0)

func on_piece_collision(game: Node, player_id: int, piece: AlkkagiPiece, other: AlkkagiPiece) -> void:
	if piece.owner_id != player_id or other.owner_id == player_id or piece.transformation != "KING" or not piece.king_shockwave_available:
		return
	piece.king_shockwave_available = false
	piece.refresh_physics()
	var radius := float(definition.values.get("shockwave_radius", 78.0))
	var force := float(definition.values.get("shockwave_force", 240.0))
	for target: AlkkagiPiece in game.get_pieces():
		if target == piece or target.position.distance_to(piece.position) > radius:
			continue
		var direction := piece.position.direction_to(target.position)
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
		target.sleeping = false
		target.apply_central_impulse(direction * force)
	game.animate_projectile(piece.position - Vector2(radius, 0), piece.position + Vector2(radius, 0), Color("ffbf3f"), 13.0)
