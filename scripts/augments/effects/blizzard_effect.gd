class_name BlizzardAugmentEffect
extends AugmentEffect

var cycles_left := 3
var awaiting_first_turn := false

func on_acquired(game: Node, player_id: int) -> void:
	awaiting_first_turn = game.current_player != player_id
	game.start_blizzard(-1, float(definition.values.get("friction_multiplier", 0.28)), float(definition.values.get("speed_multiplier", 1.15)))

func on_owner_cycle(game: Node) -> void:
	if awaiting_first_turn:
		awaiting_first_turn = false
		return
	if cycles_left <= 0:
		return
	cycles_left -= 1
	if cycles_left > 0:
		return
	for player_id in [1, 2]:
		for effect: AugmentEffect in game.augment_manager.effects[player_id]:
			if effect is BlizzardAugmentEffect and effect.cycles_left > 0:
				return
	game.blizzard_turns = 0
	game.board.set_blizzard(false)
	for piece: AlkkagiPiece in game.get_pieces():
		piece.field_damp_multiplier = 1.0
		piece.field_speed_multiplier = 1.0
		piece.refresh_physics()

func network_state() -> Dictionary:
	return {"cycles_left": cycles_left, "awaiting_first_turn": awaiting_first_turn}

func apply_network_state(_game: Node, state: Dictionary) -> void:
	cycles_left = int(state.get("cycles_left", cycles_left))
	awaiting_first_turn = bool(state.get("awaiting_first_turn", awaiting_first_turn))

func show_in_passive_hud() -> bool:
	return true

func status_text() -> String:
	return "남은 사이클 %d" % cycles_left
