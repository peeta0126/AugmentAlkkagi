class_name SnowballAugmentEffect
extends AugmentEffect

const SnowballScene := preload("res://scenes/effects/snowball.tscn")

var projectile_active := false
var projectile_position := Vector2.ZERO
var projectile_direction := Vector2.RIGHT
var distance_traveled := 0.0
var impact_serial := 0
var impact_position := Vector2.ZERO
var _visual: SnowballVisual
var _last_remote_impact := 0

func targeting_hint() -> String:
	return "눈덩이: 마우스로 방향을 정하고 좌클릭으로 발사 · 우클릭/Esc 취소"

func on_position_target(game: Node, player_id: int, target: Vector2) -> bool:
	var origin: Vector2 = game.player_center(player_id)
	var direction := origin.direction_to(target)
	if direction.is_zero_approx():
		game.set_skill_hint("발사 방향을 더 멀리 지정하세요.")
		return false
	projectile_active = true
	projectile_position = origin
	projectile_direction = direction
	distance_traveled = 0.0
	_ensure_visual(game)
	_visual.begin_runtime(projectile_position, projectile_direction, float(definition.values.get("radius", 9.0)))
	commit_use(game, player_id)
	return true

func update_target_preview(game: Node, player_id: int, target: Vector2) -> void:
	var origin: Vector2 = game.player_center(player_id)
	_ensure_visual(game)
	_visual.show_preview(origin, target, float(definition.values.get("range", 500.0)))

func cancel_active() -> void:
	if is_instance_valid(_visual) and not projectile_active:
		_visual.queue_free()
		_visual = null

func blocks_turn_resolution() -> bool:
	return projectile_active

func on_physics_tick(game: Node, player_id: int, delta: float) -> void:
	if not projectile_active:
		return
	var previous := projectile_position
	var step := float(definition.values.get("speed", 720.0)) * delta
	projectile_position += projectile_direction * step
	distance_traveled += step
	for piece: AlkkagiPiece in game.get_pieces():
		if piece.owner_id == player_id:
			continue
		if _distance_to_segment(piece.position, previous, projectile_position) <= piece.visual_radius + float(definition.values.get("radius", 9.0)):
			piece.apply_snow(maxi(int(definition.duration_turns), 1))
			_finish_projectile(true)
			return
	if distance_traveled >= float(definition.values.get("range", 500.0)) or not AlkkagiBoard.BOARD_RECT.grow(32.0).has_point(projectile_position):
		_finish_projectile(false)
		return
	if is_instance_valid(_visual):
		_visual.update_runtime(projectile_position, projectile_direction)

func network_state() -> Dictionary:
	return {
		"active": projectile_active,
		"position": projectile_position,
		"direction": projectile_direction,
		"distance": distance_traveled,
		"impact_serial": impact_serial,
		"impact_position": impact_position
	}

func apply_network_state(game: Node, state: Dictionary) -> void:
	projectile_active = bool(state.get("active", false))
	projectile_position = state.get("position", Vector2.ZERO)
	projectile_direction = state.get("direction", Vector2.RIGHT)
	distance_traveled = float(state.get("distance", 0.0))
	var remote_impact := int(state.get("impact_serial", 0))
	if remote_impact > _last_remote_impact:
		_last_remote_impact = remote_impact
		impact_position = state.get("impact_position", projectile_position)
		_ensure_visual(game)
		_visual.update_runtime(impact_position, projectile_direction)
		_visual.finish(true)
		_visual = null
	elif projectile_active:
		_ensure_visual(game)
		_visual.begin_runtime(projectile_position, projectile_direction, float(definition.values.get("radius", 9.0)))
	else:
		_clear_visual(false)

func _finish_projectile(hit: bool) -> void:
	projectile_active = false
	impact_position = projectile_position
	if hit:
		impact_serial += 1
	_clear_visual(hit)

func _ensure_visual(game: Node) -> void:
	if is_instance_valid(_visual):
		return
	_visual = SnowballScene.instantiate() as SnowballVisual
	game.world.add_child(_visual)

func _clear_visual(hit: bool) -> void:
	if is_instance_valid(_visual):
		_visual.finish(hit)
	_visual = null

static func _distance_to_segment(point: Vector2, from: Vector2, to: Vector2) -> float:
	var segment := to - from
	if segment.is_zero_approx():
		return point.distance_to(from)
	var ratio := clampf((point - from).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(from + segment * ratio)
