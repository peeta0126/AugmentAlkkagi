class_name TankAugmentEffect
extends AugmentEffect

func on_acquired(game: Node, player_id: int) -> void:
	for piece in game.get_pieces():
		if piece.owner_id == player_id:
			apply_to_piece(piece)

func apply_to_piece(piece: AlkkagiPiece) -> void:
	piece.apply_tank(float(definition.values.get("size_multiplier", 1.25)), float(definition.values.get("mass_multiplier", 1.8)))
