class_name StealthAugmentEffect
extends AugmentEffect

func on_piece_target(game: Node, player_id: int, piece: AlkkagiPiece) -> bool:
	if piece.owner_id != player_id or piece.hidden_from_player != 0:
		return false
	piece.set_stealth(2 if player_id == 1 else 1, maxi(definition.duration_turns, 1))
	game.update_piece_visibility()
	commit_use(game, player_id)
	return true
