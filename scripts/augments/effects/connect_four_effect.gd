class_name ConnectFourAugmentEffect
extends AugmentEffect

func check_special_victory(game: Node, player_id: int) -> bool:
	return game.check_connect_four(player_id, float(definition.values.get("grid_tolerance", 14.0)))
