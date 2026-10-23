class_name TripleShotAugmentEffect
extends AugmentEffect

func transform_shot(game: Node, player_id: int, piece: AlkkagiPiece, impulse: Vector2) -> bool:
	if piece.fragment_factor < 1.0:
		return false
	game.split_piece_and_launch(piece, player_id, impulse, float(definition.values.get("spread_degrees", 12.0)))
	return true
