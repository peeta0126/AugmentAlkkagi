class_name BlizzardAugmentEffect
extends AugmentEffect

func activate_immediate(game: Node, player_id: int) -> void:
	game.start_blizzard(int(definition.duration_turns) + 1, float(definition.values.get("damp_bonus", 2.0)), float(definition.values.get("speed_multiplier", 0.75)))
	commit_use(game, player_id)
