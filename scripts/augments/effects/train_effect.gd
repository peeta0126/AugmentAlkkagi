class_name TrainAugmentEffect
extends AugmentEffect

enum Phase { FIRST_PASS, PREVIEW, WARNED_PASS }

var phase := Phase.FIRST_PASS
var warned_path: Dictionary = {}

func on_acquired(game: Node, _player_id: int) -> void:
	phase = Phase.FIRST_PASS
	warned_path.clear()
	game.board.remove_field_visual(_warning_key())

func on_global_turn_ended(game: Node, _completed_player: int) -> void:
	match phase:
		Phase.FIRST_PASS:
			game.run_train_event_path(game.choose_train_path(), float(definition.values.get("knockback", 760.0)))
			game.begin_train_movement()
			phase = Phase.PREVIEW
		Phase.PREVIEW:
			warned_path = game.choose_train_path()
			_show_warning(game)
			phase = Phase.WARNED_PASS
		Phase.WARNED_PASS:
			game.run_train_event_path(warned_path, float(definition.values.get("knockback", 760.0)))
			game.begin_train_movement()
			game.board.remove_field_visual(_warning_key())
			warned_path.clear()
			phase = Phase.PREVIEW

func status_text() -> String:
	if phase == Phase.WARNED_PASS:
		return "다음 턴 종료: 예고 경로 통과"
	if phase == Phase.FIRST_PASS:
		return "다음 턴 종료: 첫 기차 통과"
	return "다음 턴 종료: 경로 예고"

func show_in_passive_hud() -> bool:
	return true

func network_state() -> Dictionary:
	return {"phase": phase, "path": warned_path.duplicate()}

func apply_network_state(game: Node, state: Dictionary) -> void:
	phase = int(state.get("phase", Phase.FIRST_PASS)) as Phase
	warned_path = state.get("path", {}).duplicate()
	if phase == Phase.WARNED_PASS and not warned_path.is_empty():
		_show_warning(game)
	else:
		game.board.remove_field_visual(_warning_key())

func _show_warning(game: Node) -> void:
	game.board.set_field_visual(_warning_key(), {
		"type": "train_warning",
		"from": warned_path.get("from", Vector2.ZERO),
		"to": warned_path.get("to", Vector2.ZERO),
	})

func _warning_key() -> String:
	return "train_warning_%d" % owner_id
