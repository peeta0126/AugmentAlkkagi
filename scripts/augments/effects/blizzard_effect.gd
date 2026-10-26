class_name BlizzardAugmentEffect
extends AugmentEffect

func on_acquired(game: Node, _player_id: int) -> void:
	game.start_blizzard(-1, float(definition.values.get("friction_multiplier", 0.28)), float(definition.values.get("speed_multiplier", 1.15)))

func show_in_passive_hud() -> bool:
	return true

func status_text() -> String:
	return "게임 종료까지 유지"