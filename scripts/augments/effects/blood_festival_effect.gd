class_name BloodFestivalAugmentEffect
extends AugmentEffect

func grants_bonus_turn(game: Node, player_id: int, opponent_eliminated: int) -> bool:
	if opponent_eliminated <= 0:
		return false
	var center: Vector2 = game.player_center(player_id)
	game.board.add_effect_line(center + Vector2(-42, -18), center + Vector2(42, 18), Color("d9344f"), 1.0, 8.0)
	return true
