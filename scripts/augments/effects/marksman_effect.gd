class_name MarksmanAugmentEffect
extends AugmentEffect

func guide_multiplier() -> float:
	return 1.18

func adjust_pointer(game: Node, player_id: int, piece: AlkkagiPiece, pointer: Vector2) -> Vector2:
	var intended := piece.position - pointer
	if intended.length() < 12.0:
		return pointer
	var best_angle := deg_to_rad(float(definition.values.get("max_correction_degrees", 6.0)))
	var best_direction := intended.normalized()
	for target in game.get_pieces():
		if target.owner_id == player_id:
			continue
		var direction: Vector2 = (target.position - piece.position).normalized()
		var angle := absf(best_direction.angle_to(direction))
		if angle < deg_to_rad(float(definition.values.get("search_degrees", 12.0))) and angle < best_angle:
			best_angle = angle
			best_direction = direction
	var original_direction := intended.normalized()
	var corrected := original_direction.slerp(best_direction, 0.55)
	return piece.position - corrected * intended.length()
