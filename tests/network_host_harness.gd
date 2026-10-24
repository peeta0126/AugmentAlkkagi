extends SceneTree

const TEST_PORT := 7787
var game: Node
var selection_order := "client_first"

func _init() -> void:
	call_deferred("run_test")

func wait_until(predicate: Callable, seconds: float = 8.0) -> bool:
	var elapsed := 0.0
	while elapsed < seconds:
		if predicate.call():
			return true
		await create_timer(0.05).timeout
		elapsed += 0.05
	return false

func fail(message: String) -> void:
	push_error("NETWORK HOST FAIL: " + message)
	if game and game.network_manager:
		game.network_manager.shutdown(false)
	quit(1)

func run_test() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--selection-order="):
			selection_order = argument.trim_prefix("--selection-order=")
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	if game.network_manager.create_host(TEST_PORT) != OK:
		fail("server creation")
		return
	game.online_mode = true
	game.online_is_host = true
	game.local_player_id = 1
	game.network_manager.set_piece_count(5)
	game.network_manager.set_ready(true)
	if not await wait_until(func(): return bool(game.network_manager.connected_players[2])):
		fail("client connection timeout")
		return
	if not await wait_until(func(): return bool(game.network_manager.ready_state[2])):
		fail("client ready timeout")
		return
	# Seed 1 keeps Wall Maria in player 2's initial offer after the v2 catalog expansion.
	game.augment_manager.rng.seed = 1
	if not game.network_manager.start_match():
		fail("match start rejected")
		return
	if not await wait_until(func(): return game.selection_player == 1 and not game.current_choices.is_empty()):
		fail("host augment offer")
		return
	if selection_order == "client_first":
		if not await wait_until(func(): return bool(game.network_manager.selection_completed[2])):
			fail("client-first choice was not received")
			return
	elif selection_order == "simultaneous":
		await create_timer(0.10).timeout
	game._choose_augment(game.current_choices[0].id)
	if not await wait_until(func(): return game.board != null, 10.0):
		fail("world start timeout")
		return
	if game.count_owner(1) != 5 or game.count_owner(2) != 5:
		fail("piece count mismatch")
		return
	for round_index in 6:
		var host_piece: AlkkagiPiece
		for piece in game.get_pieces():
			if piece.owner_id == 1:
				host_piece = piece
				break
		game._on_piece_pressed(host_piece)
		if round_index == 0:
			var right_click := InputEventMouseButton.new()
			right_click.button_index = MOUSE_BUTTON_RIGHT
			right_click.pressed = true
			game._unhandled_input(right_click)
			if game.state_machine.current != GameStateMachine.State.PLAYER_AIMING or game.round_count != 0:
				fail("host aim cancellation consumed action")
				return
			game._on_piece_pressed(host_piece)
		game.fire_selected(host_piece.global_position + Vector2(48, 0))
		if not await wait_until(func(): return game.current_player == 2 and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, 10.0):
			fail("host shot did not resolve")
			return
		if round_index not in [2, 5]:
			if not await wait_until(func(): return game.current_player == 1 and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, 12.0):
				fail("client shot request did not resolve")
				return
			if round_index == 0 and game.temporary_walls.is_empty():
				fail("wall maria active request did not create a wall")
				return
		else:
			if not await wait_until(func(): return game.state_machine.current == GameStateMachine.State.AUGMENT_SELECTION and game.selection_player == 1 and not game.current_choices.is_empty(), 12.0):
				fail("shared reward selection did not open")
				return
			if not await wait_until(func(): return bool(game.network_manager.selection_completed[2]), 8.0):
				fail("client reward choice was not received")
				return
			var stage: int = game.network_manager.active_selection_stage
			var client_choice: StringName = game.network_manager.pending_choices[2]
			var pending_count: int = game.network_manager.pending_choices.size()
			var client_peer: int = game.network_manager._peer_for_player(2)
			var last_sequence: int = int(game.network_manager.last_sequences.get(client_peer, 0))
			if game.network_manager._valid_sequence(client_peer, last_sequence, "duplicate augment test"):
				fail("duplicate sequence was accepted")
				return
			game.network_manager._host_process_augment_choice(2, stage, client_choice, 99999)
			if game.network_manager.pending_choices.size() != pending_count:
				fail("duplicate reward choice changed pending state")
				return
			var bad_stage_choice := StringName(game.network_manager.offers[1].ids[0])
			game.network_manager._host_process_augment_choice(1, stage + 100, bad_stage_choice, 99998)
			if bool(game.network_manager.selection_completed[1]):
				fail("bad stage choice was accepted")
				return
			game._choose_augment(game.current_choices[0].id)
			var expected_count := 2 if round_index == 2 else 3
			if not await wait_until(func(): return game.state_machine.current == GameStateMachine.State.PLAYER_AIMING and game.augment_manager.owned[1].size() == expected_count and game.augment_manager.owned[2].size() == expected_count, 10.0):
				fail("both reward choices did not complete")
				return
	if game.round_count != 6:
		fail("shared sixth-round count mismatch")
		return
	await create_timer(0.75).timeout
	print("PASS: ENet host authoritative localhost integration")
	game.network_manager.shutdown(false)
	quit(0)
