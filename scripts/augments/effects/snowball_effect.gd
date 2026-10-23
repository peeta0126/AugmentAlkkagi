class_name SnowballAugmentEffect
extends AugmentEffect

func on_piece_target(game: Node, player_id: int, piece: AlkkagiPiece) -> bool:
	if piece.owner_id == player_id:
		return false
	piece.apply_snow(int(definition.duration_turns))
	game.animate_projectile(game.player_center(player_id), piece.position, Color("e8f8ff"), 7.0)
	game.board.add_effect_line(game.player_center(player_id), piece.position, Color("dff7ff"), 0.7, 6.0)
	commit_use(game, player_id)
	return true
