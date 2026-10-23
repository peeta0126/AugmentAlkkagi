class_name CoupAugmentEffect
extends AugmentEffect

func activate_immediate(game: Node, player_id: int) -> void:
	game.swap_all_owners()
	commit_use(game, player_id)
