class_name GravityFieldAugmentEffect
extends AugmentEffect

var active := false
var has_center := false
var center_position := Vector2.ZERO
var seconds_left := 0.0

func blocks_turn_resolution() -> bool:
	return active

func on_position_target(game: Node, player_id: int, position: Vector2) -> bool:
	if not can_activate(game, player_id) or has_center or active or not position.is_finite() or not AlkkagiBoard.BOARD_RECT.has_point(position):
		return false
	has_center = true
	center_position = position
	_update_visual(game)
	commit_use(game, player_id)
	return true

func after_shot(game: Node, player_id: int, shot_piece: AlkkagiPiece) -> void:
	if not has_center or player_id != owner_id or not is_instance_valid(shot_piece) or shot_piece.owner_id != owner_id:
		return
	has_center = false
	active = true
	seconds_left = float(definition.values.get("duration_seconds", 1.6))
	_update_visual(game)

func on_physics_tick(game: Node, _player_id: int, delta: float) -> void:
	if not active:
		return
	seconds_left -= delta
	var radius := float(definition.values.get("radius", 200.0))
	var force := float(definition.values.get("pull_force", 960.0))
	for piece: AlkkagiPiece in game.get_pieces():
		var distance := piece.position.distance_to(center_position)
		if distance <= 1.0 or distance > radius:
			continue
		piece.sleeping = false
		piece.apply_central_impulse(piece.position.direction_to(center_position) * force * delta * (1.0 - distance / radius))
	if seconds_left <= 0.0:
		active = false
	_update_visual(game)

func network_state() -> Dictionary:
	return {"active": active, "has_center": has_center, "position": center_position, "seconds": seconds_left}

func apply_network_state(game: Node, state: Dictionary) -> void:
	active = bool(state.get("active", false))
	has_center = bool(state.get("has_center", false))
	center_position = state.get("position", Vector2.ZERO)
	seconds_left = float(state.get("seconds", 0.0))
	_update_visual(game)

func status_text() -> String:
	if active:
		return "발동 중"
	if has_center:
		return "다음 발사 대기"
	return super.status_text()

func _update_visual(game: Node) -> void:
	if game.board == null:
		return
	var key := "gravity_%d" % owner_id
	if active or has_center:
		game.board.set_field_visual(key, {"type": "gravity", "position": center_position, "radius": float(definition.values.get("radius", 200.0))})
	else:
		game.board.remove_field_visual(key)
