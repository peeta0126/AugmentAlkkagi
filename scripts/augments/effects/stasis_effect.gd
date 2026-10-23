class_name StasisAugmentEffect
extends AugmentEffect

func on_piece_target(game: Node, player_id: int, piece: AlkkagiPiece) -> bool:
	if piece.owner_id != player_id:
		return false
	piece.set_stasis(int(definition.duration_turns) + 1)
	game.board.add_effect_line(piece.position + Vector2(-18, 0), piece.position + Vector2(18, 0), Color("ffd76a"), 0.7, 5.0)
	commit_use(game, player_id)
	return true
