class_name BlizzardAugmentEffect
extends AugmentEffect

func activate_immediate(game: Node, player_id: int) -> void:
	game.start_blizzard(int(definition.duration_turns) + 1, float(definition.values.get("friction_multiplier", 0.28)), float(definition.values.get("speed_multiplier", 1.15)))
	commit_use(game, player_id)
