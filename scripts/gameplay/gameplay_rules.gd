class_name GameplayRules
extends RefCounted

const MIN_PIECES := 3
const MAX_PIECES := 5
const DEFAULT_PIECES := 5
const AUGMENT_TURN_INTERVAL := 4
const BALANCE: PhysicsBalance = preload("res://resources/balance/default_physics_balance.tres")

static func clamp_piece_count(value: int) -> int:
	return clampi(value, MIN_PIECES, MAX_PIECES)

static func shot_impulse(origin: Vector2, pointer: Vector2, max_drag: float = -1.0, impulse_multiplier: float = 1.0) -> Vector2:
	# 드래그 비례 힘을 만든 뒤 최대 충격량과 증강 배율을 최종 단계에서 한 번만 적용한다.
	var resolved_drag := BALANCE.drag_distance if max_drag <= 0.0 else max_drag
	var pull := (origin - pointer).limit_length(resolved_drag)
	if pull.is_zero_approx():
		return Vector2.ZERO
	var range_multiplier := resolved_drag / BALANCE.drag_distance
	var capped_strength := minf(pull.length() * BALANCE.base_launch_impulse, BALANCE.max_launch_impulse * range_multiplier)
	return pull.normalized() * capped_strength * impulse_multiplier

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
