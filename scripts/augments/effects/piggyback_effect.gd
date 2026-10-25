class_name PiggybackAugmentEffect
extends AugmentEffect

func on_piece_target(game: Node, player_id: int, piece: AlkkagiPiece) -> bool:
	if piece.owner_id != player_id:
		return false
	var allies: Array[AlkkagiPiece] = []
	for candidate: AlkkagiPiece in game.get_pieces():
		if candidate.owner_id == player_id:
			allies.append(candidate)
	if allies.size() <= 1:
		game.set_skill_hint("합체할 다른 아군 돌이 없습니다.")
		return false
	var absorbed := 0
	for ally: AlkkagiPiece in allies:
		if ally == piece:
			continue
		game.animate_projectile(ally.position, piece.position, Color("e5b56d"), 4.0)
		ally.queue_free()
		absorbed += 1
	piece.carried_count += absorbed
	piece.merge_size_step = float(definition.values.get("size_step", 0.22))
	piece.merge_size_cap = float(definition.values.get("size_cap", 1.8))
	piece.merge_mass_step = float(definition.values.get("mass_step", 0.9))
	piece.refresh_physics()
	var safe_rect := AlkkagiBoard.BOARD_RECT.grow(-piece.visual_radius)
	piece.position = Vector2(
		clampf(piece.position.x, safe_rect.position.x, safe_rect.end.x),
		clampf(piece.position.y, safe_rect.position.y, safe_rect.end.y)
	)
	commit_use(game, player_id)
	return true
