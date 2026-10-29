class_name EarthquakeAugmentEffect
extends AugmentEffect

var active := false
var cracks: Array[Dictionary] = []
var turns_left := 0
var activation_delay := 0.0

func activate_immediate(game: Node, player_id: int) -> void:
	cracks.clear()
	var count := int(definition.values.get("crack_count", 3))
	var width := float(definition.values.get("width", 18.0))
	var attempts := 0
	while cracks.size() < count and attempts < 80:
		attempts += 1
		var center: Vector2 = Vector2(game.augment_manager.rng.randf_range(AlkkagiBoard.BOARD_RECT.position.x + 55.0, AlkkagiBoard.BOARD_RECT.end.x - 55.0), game.augment_manager.rng.randf_range(AlkkagiBoard.BOARD_RECT.position.y + 55.0, AlkkagiBoard.BOARD_RECT.end.y - 55.0))
		var angle: float = game.augment_manager.rng.randf_range(0.0, PI)
		var half_length: float = game.augment_manager.rng.randf_range(55.0, 95.0)
		var from: Vector2 = center - Vector2.from_angle(angle) * half_length
		var to: Vector2 = center + Vector2.from_angle(angle) * half_length
		var safe := true
		for piece: AlkkagiPiece in game.get_pieces():
			if _distance_to_segment(piece.position, from, to) < piece.visual_radius + width + 12.0:
				safe = false
				break
		if safe:
			cracks.append({"from": from, "to": to})
	active = not cracks.is_empty()
	turns_left = maxi(definition.duration_turns, 1)
	activation_delay = 0.35
	_update_visual(game)
	commit_use(game, player_id)

func on_physics_tick(game: Node, _player_id: int, delta: float) -> void:
	if not active:
		return
	activation_delay = maxf(activation_delay - delta, 0.0)
	if activation_delay > 0.0:
		return
	var width := float(definition.values.get("width", 18.0))
	for piece: AlkkagiPiece in game.get_pieces():
		if piece.invulnerable:
			continue
		for crack: Dictionary in cracks:
			if _distance_to_segment(piece.position, crack.from, crack.to) <= width * 0.5 + piece.visual_radius * 0.35:
				piece.queue_free()
				break

func on_turn_ended(game: Node, player_id: int) -> void:
	super.on_turn_ended(game, player_id)
	if not active:
		return
	turns_left -= 1
	if turns_left <= 0:
		active = false
		cracks.clear()
	_update_visual(game)

func network_state() -> Dictionary:
	return {"active": active, "cracks": cracks, "turns": turns_left}

func apply_network_state(game: Node, state: Dictionary) -> void:
	active = bool(state.get("active", false))
	cracks.assign(state.get("cracks", []))
	turns_left = int(state.get("turns", 0))
	_update_visual(game)

func _update_visual(game: Node) -> void:
	if game.board == null:
		return
	var key := "earthquake_%d" % owner_id
	if active:
		game.board.set_field_visual(key, {"type": "cracks", "cracks": cracks, "width": float(definition.values.get("width", 18.0))})
	else:
		game.board.remove_field_visual(key)

static func _distance_to_segment(point: Vector2, from: Vector2, to: Vector2) -> float:
	var segment := to - from
	if segment.is_zero_approx():
		return point.distance_to(from)
	var ratio := clampf((point - from).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(from + segment * ratio)
