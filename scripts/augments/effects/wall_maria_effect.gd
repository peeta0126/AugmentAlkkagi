class_name WallMariaAugmentEffect
extends AugmentEffect

var vertical := false
var preview: WallMariaVisual
var wall_ids: Array[int] = []

func on_position_target(game: Node, player_id: int, position: Vector2) -> bool:
	var wall_rotation: float = PI * 0.5 if vertical else 0.0
	if not game.can_place_wall(position, wall_rotation):
		return false
	if not game.spawn_wall(position, int(definition.duration_turns), wall_rotation):
		return false
	var wall: TemporaryWall = game.temporary_walls.back()
	wall.cycle_based = true
	wall_ids.append(wall.wall_id)
	_clear_preview()
	commit_use(game, player_id)
	return true

func on_owner_cycle(game: Node) -> void:
	for wall: TemporaryWall in game.temporary_walls.duplicate():
		if not is_instance_valid(wall) or wall.wall_id not in wall_ids:
			continue
		wall.turns_left -= 1
		if wall.turns_left <= 0:
			wall_ids.erase(wall.wall_id)
			game.temporary_walls.erase(wall)
			wall.queue_free()

func network_state() -> Dictionary:
	return {"wall_ids": wall_ids}

func apply_network_state(_game: Node, state: Dictionary) -> void:
	wall_ids.assign(state.get("wall_ids", []))

func update_target_preview(game: Node, _player_id: int, position: Vector2) -> void:
	if preview == null or not is_instance_valid(preview):
		preview = game.create_wall_preview()
	var wall_rotation: float = PI * 0.5 if vertical else 0.0
	preview.show_preview(position, wall_rotation, game.can_place_wall(position, wall_rotation))

func on_targeting_key(game: Node, player_id: int, keycode: Key) -> bool:
	if keycode != KEY_R:
		return false
	vertical = not vertical
	update_target_preview(game, player_id, game.get_global_mouse_position())
	game.set_skill_hint(targeting_hint())
	return true

func targeting_hint() -> String:
	var direction := "세로" if vertical else "가로"
	return "월마리아: %s · R 방향 전환 · 좌클릭 설치 · 우클릭/Esc 취소" % direction

func targeting_option() -> int:
	return 1 if vertical else 0

func apply_targeting_option(option: int) -> void:
	vertical = option == 1

func cancel_active() -> void:
	_clear_preview()

func _clear_preview() -> void:
	if is_instance_valid(preview):
		preview.queue_free()
	preview = null
