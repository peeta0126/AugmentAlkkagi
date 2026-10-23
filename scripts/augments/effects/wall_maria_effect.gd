class_name WallMariaAugmentEffect
extends AugmentEffect

func on_position_target(game: Node, player_id: int, position: Vector2) -> bool:
	if not AlkkagiBoard.BOARD_RECT.grow(-35.0).has_point(position) or game.position_overlaps_piece(position, 85.0):
		return false
	game.spawn_wall(position, int(definition.duration_turns) + 1)
	commit_use(game, player_id)
	return true
