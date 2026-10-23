class_name SonicBoomAugmentEffect
extends AugmentEffect

func impulse_multiplier() -> float:
	return float(definition.values.get("impulse_multiplier", 1.6))

func before_shot(piece: AlkkagiPiece) -> void:
	piece.activate_sonic_trail(piece.speed_cap)
