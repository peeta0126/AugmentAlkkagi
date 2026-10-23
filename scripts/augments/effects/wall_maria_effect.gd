class_name WallMariaAugmentEffect
extends AugmentEffect

func on_position_target(game: Node, player_id: int, position: Vector2) -> bool:
	var wall_rotation: float = 0.0 if game.augment_manager.rng.randi() % 2 == 0 else PI * 0.5
	if not game.can_place_wall(position, wall_rotation):
		return false
	if not game.spawn_wall(position, int(definition.duration_turns) + 1, wall_rotation):
		return false
	commit_use(game, player_id)
	return true
