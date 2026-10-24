class_name WishAugmentEffect
extends AugmentEffect

var active := false
var balls: Array[Dictionary] = []
var collected := 0

func activate_immediate(game: Node, player_id: int) -> void:
	balls.clear()
	collected = 0
	var radius := float(definition.values.get("orb_radius", 10.0))
	var attempts := 0
	while balls.size() < 7 and attempts < 240:
		attempts += 1
		var position := Vector2(game.augment_manager.rng.randf_range(AlkkagiBoard.BOARD_RECT.position.x + 32.0, AlkkagiBoard.BOARD_RECT.end.x - 32.0), game.augment_manager.rng.randf_range(AlkkagiBoard.BOARD_RECT.position.y + 32.0, AlkkagiBoard.BOARD_RECT.end.y - 32.0))
		if game.position_overlaps_piece(position, radius + 8.0) or not game.can_place_collectible(position, radius):
			continue
		var overlaps_ball := false
		for ball: Dictionary in balls:
			if position.distance_to(ball.position) < radius * 3.0:
				overlaps_ball = true
				break
		if not overlaps_ball:
			balls.append({"number": balls.size() + 1, "position": position})
	active = balls.size() == 7
	_update_visual(game)
	commit_use(game, player_id)
	_refresh_hud(game)

func on_physics_tick(game: Node, player_id: int, _delta: float) -> void:
	if not active:
		return
	var radius := float(definition.values.get("orb_radius", 10.0))
	var previous_collected := collected
	for ball: Dictionary in balls.duplicate():
		for piece: AlkkagiPiece in game.get_pieces():
			if piece.owner_id == player_id and piece.position.distance_to(ball.position) <= piece.visual_radius + radius:
				balls.erase(ball)
				collected += 1
				game.board.add_effect_line(ball.position + Vector2(-12, 0), ball.position + Vector2(12, 0), Color("ffae35"), 0.7, 6.0)
				break
	if collected >= 7:
		active = false
	_update_visual(game)
	if collected != previous_collected:
		_refresh_hud(game)

func check_special_victory(_game: Node, _player_id: int) -> bool:
	return collected >= 7

func status_text() -> String:
	return "%d/7 수집" % collected

func network_state() -> Dictionary:
	return {"active": active, "balls": balls, "collected": collected}

func apply_network_state(game: Node, state: Dictionary) -> void:
	var previous_collected := collected
	active = bool(state.get("active", false))
	balls.assign(state.get("balls", []))
	collected = int(state.get("collected", 0))
	_update_visual(game)
	if collected != previous_collected:
		_refresh_hud(game)

func _update_visual(game: Node) -> void:
	if game.board == null:
		return
	var key := "wish_%d" % owner_id
	if active or not balls.is_empty():
		game.board.set_field_visual(key, {"type": "dragon_balls", "balls": balls})
	else:
		game.board.remove_field_visual(key)

func _refresh_hud(game: Node) -> void:
	if game.count_label != null:
		game.update_hud(game.hint_label.text if game.hint_label != null else "")
