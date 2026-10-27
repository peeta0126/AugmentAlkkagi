extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func run_test() -> void:
	for refresh_enabled in [false, true]:
		for chaos_enabled in [false, true]:
			await _test_mode_combination(refresh_enabled, chaos_enabled)
	await _test_lobby_mode_authority()
	if failures == 0:
		print("PASS: placement, independent mode combinations, refresh sharing, and turn retention")
	quit(failures)

func _test_mode_combination(refresh_enabled: bool, chaos_enabled: bool) -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.refresh_mode = refresh_enabled
	game.chaos_mode = chaos_enabled
	game.begin_match()
	await process_frame
	check(game.state_machine.current == GameStateMachine.State.PIECE_PLACEMENT, "mode %s/%s starts in placement" % [refresh_enabled, chaos_enabled])
	check(game.validate_player_placement(1) and game.validate_player_placement(2), "default positions remain valid")
	var black_piece: AlkkagiPiece
	var other_black: AlkkagiPiece
	for piece in game.get_pieces():
		if piece.owner_id == 1:
			if black_piece == null:
				black_piece = piece
			else:
				other_black = piece
	check(not game.is_valid_piece_placement(black_piece, Vector2(10, 10)), "board outside placement is rejected")
	check(not game.is_valid_piece_placement(black_piece, Vector2(AlkkagiBoard.BOARD_RECT.get_center().x, AlkkagiBoard.BOARD_RECT.end.y - 30.0)), "opponent zone placement is rejected")
	check(not game.is_valid_piece_placement(black_piece, other_black.position), "overlapping placement is rejected")
	game._confirm_placement()
	check(bool(game.placement_completed[1]) and not bool(game.placement_completed[2]), "first local player can lock placement")
	game._confirm_placement()
	await process_frame
	var expected_picks := 2 if chaos_enabled else 1
	check(game.selection_pick_target == expected_picks and game.selection_pick_index == 1, "selection count matches mode")
	check(game.current_choices.size() == GameplayRules.AUGMENT_CHOICES, "selection offers configured card count")
	if refresh_enabled:
		game._refresh_augment_choices()
		await process_frame
		check(game.selection_refresh_used, "refresh is consumed once")
		var ids_after_first_refresh: Array[StringName] = []
		for definition in game.current_choices:
			ids_after_first_refresh.append(definition.id)
		game._refresh_augment_choices()
		var ids_after_second_request: Array[StringName] = []
		for definition in game.current_choices:
			ids_after_second_request.append(definition.id)
		check(ids_after_first_refresh == ids_after_second_request, "second refresh request is ignored")
	for player_id in [1, 2]:
		for pick in expected_picks:
			check(game.selection_player == player_id, "selection remains with player until all picks complete")
			game._choose_augment(game.current_choices[0].id)
			await process_frame
			if chaos_enabled and pick == 0:
				check(game.selection_player == player_id and game.selection_pick_index == 2, "chaos advances to 2/2 without changing player")
				if refresh_enabled and player_id == 1:
					check(game.selection_refresh_used, "refresh usage persists across chaos picks")
	check(game.augment_manager.owned[1].size() == expected_picks and game.augment_manager.owned[2].size() == expected_picks, "mode grants exact augment count")
	check(game.current_player == 1 and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, "selection completion preserves the shooter's turn")
	# Isolate the ordinary turn transition from randomly selected active/passive effects.
	game.augment_manager.effects[1].clear()
	game.augment_manager.effects[2].clear()
	game.state_machine.transition(GameStateMachine.State.PIECES_MOVING)
	game.resolve_turn()
	check(game.current_player == 2 and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, "turn changes only after shot resolution")
	game.queue_free()
	await process_frame

func _test_lobby_mode_authority() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var network = game.network_manager
	network.mode = network.Mode.HOST
	network.local_player_id = 1
	network.ready_state = {1: true, 2: true}
	network.set_modes(true, true)
	check(network.refresh_mode and network.chaos_mode, "host can enable both independent modes")
	check(not bool(network.ready_state[2]), "mode change clears guest ready state")
	network.mode = network.Mode.CLIENT
	network.set_modes(false, false)
	check(network.refresh_mode and network.chaos_mode, "guest cannot change room modes")
	var lobby := (load("res://scenes/ui/online_lobby.tscn") as PackedScene).instantiate() as OnlineLobby
	root.add_child(lobby)
	lobby.show_lobby("123456", false, "guest", Color.WHITE)
	lobby.update_lobby({1: true, 2: false}, {1: true, 2: true}, 5, 2, false, true, true)
	check(lobby.refresh_mode_toggle.button_pressed and lobby.chaos_mode_toggle.button_pressed, "guest lobby displays both synchronized modes")
	check(lobby.refresh_mode_toggle.disabled and lobby.chaos_mode_toggle.disabled, "guest lobby mode controls are read-only")
	lobby.queue_free()
	game.queue_free()
	await process_frame
