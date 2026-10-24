class_name LanternAugmentEffect
extends AugmentEffect

var installed := false
var lantern_position := Vector2.ZERO
var turns_left := 0
var pieces_inside: Dictionary = {}

func on_position_target(game: Node, player_id: int, position: Vector2) -> bool:
	var object_radius := float(definition.values.get("object_radius", 18.0))
	if not AlkkagiBoard.BOARD_RECT.grow(-object_radius).has_point(position) or game.position_overlaps_piece(position, object_radius):
		return false
	installed = true
	lantern_position = position
	turns_left = maxi(definition.duration_turns, 1)
	pieces_inside.clear()
	_update_visual(game)
	commit_use(game, player_id)
	return true

func on_physics_tick(game: Node, player_id: int, _delta: float) -> void:
	if not installed:
		return
	var trigger_radius := float(definition.values.get("range", 48.0))
	var currently_inside := {}
	for piece: AlkkagiPiece in game.get_pieces():
		if piece.owner_id != player_id or piece.position.distance_to(lantern_position) > trigger_radius:
			continue
		currently_inside[piece.piece_id] = true
		if pieces_inside.has(piece.piece_id):
			continue
		var direction := piece.linear_velocity.normalized()
		if direction.is_zero_approx():
			direction = Vector2.DOWN if player_id == 1 else Vector2.UP
		piece.sleeping = false
		piece.apply_central_impulse(direction * float(definition.values.get("boost_impulse", 260.0)))
		game.board.add_effect_line(lantern_position, lantern_position + direction * 70.0, Color("ffcf5c"), 0.55, 5.0)
	pieces_inside = currently_inside

func on_turn_ended(game: Node, player_id: int) -> void:
	super.on_turn_ended(game, player_id)
	if not installed:
		return
	turns_left -= 1
	if turns_left <= 0:
		installed = false
		pieces_inside.clear()
	_update_visual(game)

func network_state() -> Dictionary:
	return {"installed": installed, "position": lantern_position, "turns": turns_left}

func apply_network_state(game: Node, state: Dictionary) -> void:
	installed = bool(state.get("installed", false))
	lantern_position = state.get("position", Vector2.ZERO)
	turns_left = int(state.get("turns", 0))
	_update_visual(game)

func _update_visual(game: Node) -> void:
	if game.board == null:
		return
	var key := "lantern_%d" % owner_id
	if installed:
		game.board.set_field_visual(key, {"type": "lantern", "position": lantern_position, "radius": float(definition.values.get("range", 48.0)), "owner": owner_id})
	else:
		game.board.remove_field_visual(key)
