class_name TrainAugmentEffect
extends AugmentEffect

func activate_immediate(game: Node, player_id: int) -> void:
	game.run_train_event(float(definition.values.get("knockback", 760.0)))
	commit_use(game, player_id)
