class_name AugmentEffect
extends RefCounted

var definition: AugmentDefinition
var owner_id := 0
var uses_left := -1
var cooldown_left := 0

func setup(source: AugmentDefinition) -> void:
	definition = source
	uses_left = definition.max_uses

func on_acquired(_game: Node, _player_id: int) -> void:
	pass

func apply_to_piece(_piece: AlkkagiPiece) -> void:
	pass

func impulse_multiplier() -> float:
	return 1.0

func max_drag_multiplier() -> float:
	return 1.0

func guide_multiplier() -> float:
	return 1.0

func before_shot(_piece: AlkkagiPiece) -> void:
	pass

func on_turn_started(_game: Node, _player_id: int) -> void:
	pass

func on_turn_ended(_game: Node, _player_id: int) -> void:
	if cooldown_left > 0:
		cooldown_left -= 1

func is_active() -> bool:
	return definition.kind == AugmentDefinition.Kind.ACTIVE or definition.kind == AugmentDefinition.Kind.FIELD

func can_activate(_game: Node, player_id: int) -> bool:
	return player_id == owner_id and cooldown_left == 0 and uses_left != 0

func begin_active(game: Node, player_id: int) -> void:
	if definition.target_mode == AugmentDefinition.TargetMode.NONE:
		activate_immediate(game, player_id)
	else:
		game.begin_skill_targeting(self, player_id)

func activate_immediate(_game: Node, _player_id: int) -> void:
	pass

func on_piece_target(_game: Node, _player_id: int, _piece: AlkkagiPiece) -> bool:
	return false

func on_position_target(_game: Node, _player_id: int, _position: Vector2) -> bool:
	return false

func commit_use(game: Node, player_id: int) -> void:
	if uses_left > 0:
		uses_left -= 1
	# 사용한 바로 그 턴의 종료에서 1 감소하므로 +1로 저장한다.
	cooldown_left = definition.cooldown_turns + 1 if definition.cooldown_turns > 0 else 0
	game.finish_active_skill(player_id, definition.consumes_turn)

func cancel_active() -> void:
	pass

func status_text() -> String:
	if uses_left == 0:
		return "사용 완료"
	if cooldown_left > 0:
		return "대기 %d턴" % cooldown_left
	return "사용 가능" if uses_left < 0 else "%d회" % uses_left

func transform_shot(_game: Node, _player_id: int, _piece: AlkkagiPiece, _impulse: Vector2) -> bool:
	return false

func on_opponent_shot(_game: Node, _player_id: int, _shot_piece: AlkkagiPiece, _impulse: Vector2) -> void:
	pass

func after_shot(_game: Node, _player_id: int, _shot_piece: AlkkagiPiece) -> void:
	pass

func grants_bonus_turn(_game: Node, _player_id: int, _opponent_eliminated: int) -> bool:
	return false

func adjust_pointer(_game: Node, _player_id: int, _piece: AlkkagiPiece, pointer: Vector2) -> Vector2:
	return pointer

func check_special_victory(_game: Node, _player_id: int) -> bool:
	return false

func on_physics_tick(_game: Node, _player_id: int, _delta: float) -> void:
	pass

func network_state() -> Dictionary:
	return {}

func apply_network_state(_game: Node, _state: Dictionary) -> void:
	pass
