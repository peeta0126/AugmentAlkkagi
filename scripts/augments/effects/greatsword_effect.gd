class_name GreatswordAugmentEffect
extends AugmentEffect

func on_piece_target(game: Node, player_id: int, piece: AlkkagiPiece) -> bool:
	if piece.owner_id != player_id:
		return false
	var radius := float(definition.values.get("radius", 120.0))
	var knockback := float(definition.values.get("knockback", 500.0))
	for target in game.get_pieces():
		if target.owner_id != player_id and target.position.distance_to(piece.position) <= radius:
			target.sleeping = false
			target.apply_central_impulse((target.position - piece.position).normalized() * knockback)
	game.board.add_effect_line(piece.position + Vector2(-radius, 0), piece.position + Vector2(radius, 0), Color("d9e4ff"), 0.45, 8.0)
	commit_use(game, player_id)
	return true
