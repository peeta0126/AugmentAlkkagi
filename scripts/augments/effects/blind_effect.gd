class_name BlindAugmentEffect
extends AugmentEffect

func activate_immediate(game: Node, player_id: int) -> void:
	var target := 2 if player_id == 1 else 1
	game.apply_blind(target, int(definition.duration_turns))
	commit_use(game, player_id)
