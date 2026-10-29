class_name DodgeAugmentEffect
extends AugmentEffect

func on_opponent_shot(game: Node, player_id: int, shot_piece: AlkkagiPiece, impulse: Vector2) -> void:
	game.try_dodge(player_id, shot_piece.position, impulse.normalized(), float(definition.values.get("chance", 0.40)), float(definition.values.get("distance", 34.0)))
