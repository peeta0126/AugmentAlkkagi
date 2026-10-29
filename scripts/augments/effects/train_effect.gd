class_name TrainAugmentEffect
extends AugmentEffect

## 기차가 지나가기 전에 경로를 먼저 보여 주는 시간(초).
const WARNING_SECONDS := 1.5

enum Phase { IDLE, WARNING }

var phase := Phase.IDLE
var warned_path: Dictionary = {}
var warning_left := 0.0

func on_acquired(game: Node, _player_id: int) -> void:
	_reset(game)

func on_global_turn_ended(game: Node, _completed_player: int) -> void:
	if phase == Phase.WARNING:
		return
	warned_path = game.choose_train_path()
	warning_left = WARNING_SECONDS
	phase = Phase.WARNING
	_show_warning(game)
	game.begin_train_movement()

func on_physics_tick(game: Node, _player_id: int, delta: float) -> void:
	if phase != Phase.WARNING:
		return
	warning_left -= delta
	if warning_left > 0.0:
		return
	var path := warned_path.duplicate()
	_reset(game)
	game.run_train_event_path(path, float(definition.values.get("knockback", 760.0)))
	game.begin_train_movement()

func blocks_turn_resolution() -> bool:
	return phase == Phase.WARNING

func status_text() -> String:
	return "경로 예고 중 · 곧 통과" if phase == Phase.WARNING else "다음 턴 종료: 경로 예고 후 통과"

func show_in_passive_hud() -> bool:
	return true

func network_state() -> Dictionary:
	return {"phase": phase, "path": warned_path.duplicate()}

func apply_network_state(game: Node, state: Dictionary) -> void:
	phase = int(state.get("phase", Phase.IDLE)) as Phase
	warned_path = state.get("path", {}).duplicate()
	if phase == Phase.WARNING and not warned_path.is_empty():
		_show_warning(game)
	else:
		game.board.remove_field_visual(_warning_key())

func _reset(game: Node) -> void:
	phase = Phase.IDLE
	warned_path.clear()
	warning_left = 0.0
	if game.board != null:
		game.board.remove_field_visual(_warning_key())

func _show_warning(game: Node) -> void:
	game.board.set_field_visual(_warning_key(), {
		"type": "train_warning",
		"from": warned_path.get("from", Vector2.ZERO),
		"to": warned_path.get("to", Vector2.ZERO),
	})

func _warning_key() -> String:
	return "train_warning_%d" % owner_id
