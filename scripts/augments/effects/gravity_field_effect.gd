class_name GravityFieldAugmentEffect
extends AugmentEffect

var active := false
var center_piece_id := -1
var center_position := Vector2.ZERO
var seconds_left := 0.0

func after_shot(game: Node, _player_id: int, shot_piece: AlkkagiPiece) -> void:
	active = true
	center_piece_id = shot_piece.piece_id
	center_position = shot_piece.position
	seconds_left = float(definition.values.get("duration_seconds", 1.6))
	_update_visual(game)

func on_physics_tick(game: Node, _player_id: int, delta: float) -> void:
	if not active:
		return
	seconds_left -= delta
	var center_piece: AlkkagiPiece = game.find_piece(center_piece_id)
	if center_piece != null and not center_piece.is_queued_for_deletion():
		center_position = center_piece.position
	var radius := float(definition.values.get("radius", 125.0))
	var force := float(definition.values.get("pull_force", 960.0))
	for piece: AlkkagiPiece in game.get_pieces():
		if piece.piece_id == center_piece_id:
			continue
		var distance := piece.position.distance_to(center_position)
		if distance <= 1.0 or distance > radius:
			continue
		piece.sleeping = false
		piece.apply_central_impulse(piece.position.direction_to(center_position) * force * delta * (1.0 - distance / radius))
	if seconds_left <= 0.0:
		active = false
	_update_visual(game)

func network_state() -> Dictionary:
	return {"active": active, "position": center_position, "seconds": seconds_left}

func apply_network_state(game: Node, state: Dictionary) -> void:
	active = bool(state.get("active", false))
	center_position = state.get("position", Vector2.ZERO)
	seconds_left = float(state.get("seconds", 0.0))
	_update_visual(game)

func _update_visual(game: Node) -> void:
	if game.board == null:
		return
	var key := "gravity_%d" % owner_id
	if active:
		game.board.set_field_visual(key, {"type": "gravity", "position": center_position, "radius": float(definition.values.get("radius", 125.0))})
	else:
		game.board.remove_field_visual(key)
