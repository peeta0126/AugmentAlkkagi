class_name GreatswordAugmentEffect
extends AugmentEffect

var knight_ids: Array[int] = []
var pending_knight_id := -1

func on_piece_target(game: Node, player_id: int, piece: AlkkagiPiece) -> bool:
	if piece.owner_id != player_id or not knight_ids.is_empty():
		return false
	knight_ids.append(piece.piece_id)
	piece.transform_as("KNIGHT", false)
	game.finish_active_skill(player_id, definition.consumes_turn)
	return true

func can_activate(game: Node, player_id: int) -> bool:
	return knight_ids.is_empty() and super.can_activate(game, player_id)

func after_shot(_game: Node, player_id: int, piece: AlkkagiPiece) -> void:
	pending_knight_id = -1
	if cooldown_left == 0 and is_instance_valid(piece) and not piece.is_queued_for_deletion() and piece.owner_id == player_id and piece.piece_id in knight_ids:
		pending_knight_id = piece.piece_id

func on_pieces_settled(game: Node, player_id: int) -> bool:
	if pending_knight_id < 0:
		return false
	var piece: AlkkagiPiece = game.find_piece(pending_knight_id)
	pending_knight_id = -1
	if not is_instance_valid(piece) or piece.is_queued_for_deletion() or piece.owner_id != player_id:
		return false
	var applied := false
	var radius := float(definition.values.get("radius", 60.0))
	var knockback := float(definition.values.get("knockback", 500.0))
	for target: AlkkagiPiece in game.get_pieces():
		if target.owner_id == player_id or target.position.distance_to(piece.position) > radius:
			continue
		var direction := piece.position.direction_to(target.position)
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
		target.sleeping = false
		target.apply_central_impulse(direction * knockback)
		applied = true
	if applied:
		cooldown_left = definition.cooldown_turns + 1 if definition.cooldown_turns > 0 else 0
		game.animate_projectile(piece.position + Vector2(-radius, 0), piece.position + Vector2(radius, 0), Color("d9e4ff"), 8.0)
	return applied

func on_global_turn_ended(_game: Node, _completed_player: int) -> void:
	pending_knight_id = -1

func network_state() -> Dictionary:
	return {"knight_ids": knight_ids, "pending_knight_id": pending_knight_id}

func apply_network_state(_game: Node, state: Dictionary) -> void:
	knight_ids.assign(state.get("knight_ids", []))
	pending_knight_id = int(state.get("pending_knight_id", -1))
