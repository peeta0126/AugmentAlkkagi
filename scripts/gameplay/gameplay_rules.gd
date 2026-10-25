class_name GameplayRules
extends RefCounted

const MIN_PIECES := 3
const MAX_PIECES := 5
const DEFAULT_PIECES := 5
const AUGMENT_ROUND_INTERVAL := 3
const MAX_AUGMENTS_PER_PLAYER := 3
const MIN_SHOT_DRAG_DISTANCE := 8.0
const WALL_SIZE := Vector2(150.0, 20.0)
const WALL_BOUNCE := 0.88
const WALL_FRICTION := 0.05
const WALL_COLLISION_LAYER := 2
const BALANCE: PhysicsBalance = preload("res://resources/balance/default_physics_balance.tres")

static func clamp_piece_count(value: int) -> int:
	return clampi(value, MIN_PIECES, MAX_PIECES)

static func clamp_outgoing_pull_vector(pull_vector: Vector2, max_drag: float) -> Vector2:
	return pull_vector.limit_length(maxf(max_drag, 0.0))

static func is_network_pull_vector_valid(pull_vector: Vector2, max_drag: float) -> bool:
	return pull_vector.length() >= MIN_SHOT_DRAG_DISTANCE and pull_vector.length() <= max_drag * 1.05

static func shot_impulse(origin: Vector2, pointer: Vector2, max_drag: float = -1.0, impulse_multiplier: float = 1.0) -> Vector2:
	# 질량 1인 일반 돌의 현재 발사 감각을 기준으로 한 속도 충격량입니다.
	# 실제 RigidBody2D 충격량은 발사 시 돌 질량을 곱해 같은 초기 속도를 만듭니다.
	var resolved_drag := BALANCE.drag_distance if max_drag <= 0.0 else max_drag
	var pull := (origin - pointer).limit_length(resolved_drag)
	if pull.is_zero_approx():
		return Vector2.ZERO
	var range_multiplier := resolved_drag / BALANCE.drag_distance
	var capped_strength := minf(pull.length() * BALANCE.base_launch_impulse, BALANCE.max_launch_impulse * range_multiplier)
	return pull.normalized() * capped_strength * impulse_multiplier

static func mass_compensated_launch_impulse(reference_impulse: Vector2, body_mass: float) -> Vector2:
	# J = m * target_delta_velocity. 충돌 이후에는 실제 body_mass가 그대로 사용됩니다.
	return reference_impulse * maxf(body_mass, 0.0)

static func starting_positions(board_rect: Rect2, owner_id: int, count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var safe_count := clamp_piece_count(count)
	# 실제 세로형 바둑판의 위/아래를 각 진영으로 사용한다.
	var y_ratio := 0.25 if owner_id == 1 else 0.75
	var spacing := minf(70.0, board_rect.size.x / float(safe_count + 2))
	var first_x := board_rect.get_center().x - spacing * float(safe_count - 1) * 0.5
	for index in safe_count:
		result.append(Vector2(first_x + spacing * index, board_rect.position.y + board_rect.size.y * y_ratio))
	return result
