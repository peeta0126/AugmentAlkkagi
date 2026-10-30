class_name KingAugmentEffect
extends AugmentEffect

var transformed_once := false

func on_physics_tick(game: Node, player_id: int, _delta: float) -> void:
	_check_touching_enemy(game, player_id)
	if transformed_once:
		return
	var rect: Rect2 = AlkkagiBoard.BOARD_RECT
	for piece: AlkkagiPiece in game.get_pieces():
		if piece.owner_id != player_id or piece.transformation == "KING":
			continue
		var enemy_edge_reached: bool = piece.position.y > rect.end.y - 28.0 if player_id == 1 else piece.position.y < rect.position.y + 28.0
		if enemy_edge_reached:
			transformed_once = true
			piece.king_size_multiplier = float(definition.values.get("size_multiplier", 1.5))
			piece.king_mass_multiplier = float(definition.values.get("mass_multiplier", 2.0))
			piece.transform_as("KING")
			game.animate_projectile(piece.position - Vector2(30, 0), piece.position + Vector2(30, 0), Color("ffd45e"), 12.0)
			break

func network_state() -> Dictionary:
	return {"transformed_once": transformed_once}

func apply_network_state(_game: Node, state: Dictionary) -> void:
	transformed_once = bool(state.get("transformed_once", false))

## 내 차례가 시작될 때마다 왕의 충격파가 다시 채워진다(차례마다 첫 적 충돌에서 한 번).
func on_owner_cycle(game: Node) -> void:
	for piece: AlkkagiPiece in game.get_pieces():
		if piece.owner_id == owner_id and piece.transformation == "KING" and not piece.king_shockwave_available:
			piece.king_shockwave_available = true
			piece.refresh_physics()

func on_piece_collision(game: Node, player_id: int, piece: AlkkagiPiece, other: AlkkagiPiece) -> void:
	if piece.owner_id != player_id or other.owner_id == player_id or piece.transformation != "KING" or not piece.king_shockwave_available:
		return
	_trigger_shockwave(game, piece)

## 왕이 움직이는 도중 이미 맞닿아 있던 적 돌을 밀 때는 새 접촉 신호가 오지 않는다.
## 그래서 움직이는 왕이 적 돌에 닿아 있으면 첫 충돌로 보고 충격파를 터뜨린다.
func _check_touching_enemy(game: Node, player_id: int) -> void:
	for piece: AlkkagiPiece in game.get_pieces():
		if piece.owner_id != player_id or piece.transformation != "KING" or not piece.king_shockwave_available:
			continue
		if piece.linear_velocity.length() < 30.0:
			continue
		for other: AlkkagiPiece in game.get_pieces():
			if other.owner_id == player_id:
				continue
			if piece.position.distance_to(other.position) <= piece.visual_radius + other.visual_radius + 3.0:
				_trigger_shockwave(game, piece)
				break

func _trigger_shockwave(game: Node, piece: AlkkagiPiece) -> void:
	piece.king_shockwave_available = false
	piece.refresh_physics()
	var radius := float(definition.values.get("shockwave_radius", 78.0))
	var force := float(definition.values.get("shockwave_force", 240.0))
	for target: AlkkagiPiece in game.get_pieces():
		if target == piece or target.position.distance_to(piece.position) > radius:
			continue
		var direction := piece.position.direction_to(target.position)
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
		target.sleeping = false
		target.apply_central_impulse(direction * force)
	game.animate_projectile(piece.position - Vector2(radius, 0), piece.position + Vector2(radius, 0), Color("ffbf3f"), 13.0)
