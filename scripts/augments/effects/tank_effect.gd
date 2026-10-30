class_name TankAugmentEffect
extends AugmentEffect

func on_piece_target(game: Node, player_id: int, piece: AlkkagiPiece) -> bool:
	if piece.owner_id != player_id or piece.is_tank:
		return false
	piece.apply_tank(float(definition.values.get("size_multiplier", 1.25)), float(definition.values.get("mass_multiplier", 1.8)))
	commit_use(game, player_id)
	return true
