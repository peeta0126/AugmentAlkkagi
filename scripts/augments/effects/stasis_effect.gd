class_name StasisAugmentEffect
extends AugmentEffect

func activate_immediate(game: Node, player_id: int) -> void:
	for piece: AlkkagiPiece in game.get_pieces():
		if piece.owner_id != player_id:
			continue
		piece.set_stasis(int(definition.duration_turns) + 1)
		game.board.add_effect_line(piece.position + Vector2(-18, 0), piece.position + Vector2(18, 0), Color("ffd76a"), 0.7, 5.0)
	commit_use(game, player_id)
