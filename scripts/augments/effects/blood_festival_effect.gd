class_name BloodFestivalAugmentEffect
extends AugmentEffect

func grants_bonus_turn(game: Node, player_id: int, opponent_eliminated: int) -> bool:
	if opponent_eliminated <= 0:
		return false
	var center: Vector2 = game.player_center(player_id)
	game.animate_projectile(center + Vector2(-42, -18), center + Vector2(42, 18), Color("d9344f"), 8.0)
	return true
