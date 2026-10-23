class_name LanternAugmentEffect
extends AugmentEffect

var source: AlkkagiPiece

func on_piece_target(game: Node, player_id: int, piece: AlkkagiPiece) -> bool:
	if piece.owner_id != player_id:
		return false
	if source == null:
		source = piece
		game.set_skill_hint("랜턴을 맞힐 다른 아군 알을 선택하세요.")
		return false
	if piece == source or source.position.distance_to(piece.position) > float(definition.values.get("range", 260.0)):
		return false
	var direction := (source.position - piece.position).normalized()
	piece.sleeping = false
	piece.apply_central_impulse(direction * float(definition.values.get("pull_impulse", 310.0)))
	game.animate_projectile(source.position, piece.position, Color("ffcf5c"), 5.0)
	game.board.add_effect_line(source.position, piece.position, Color("ffcf5c"), 0.75, 3.0)
	source = null
	commit_use(game, player_id)
	return true

func cancel_active() -> void:
	source = null
