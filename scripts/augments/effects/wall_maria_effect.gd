class_name WallMariaAugmentEffect
extends AugmentEffect

var vertical := false
var preview: WallMariaVisual

func on_position_target(game: Node, player_id: int, position: Vector2) -> bool:
	var wall_rotation: float = PI * 0.5 if vertical else 0.0
	if not game.can_place_wall(position, wall_rotation):
		return false
	if not game.spawn_wall(position, int(definition.duration_turns) + 1, wall_rotation):
		return false
	_clear_preview()
	commit_use(game, player_id)
	return true

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
