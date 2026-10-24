class_name JanggiAugmentEffect
extends AugmentEffect

const PIECES := ["SOLDIER", "CHARIOT", "CANNON", "HORSE", "ELEPHANT", "GUARD", "KING"]

func on_piece_target(game: Node, player_id: int, piece: AlkkagiPiece) -> bool:
	if piece.owner_id != player_id or piece.transformation != "":
		return false
	var kind: String = PIECES[game.augment_manager.rng.randi_range(0, PIECES.size() - 1)]
	piece.transform_as(kind, false)
	game.board.add_effect_line(piece.position + Vector2(0, -30), piece.position + Vector2(0, 30), Color("ffca67"), 0.8, 4.0)
	commit_use(game, player_id)
	return true
