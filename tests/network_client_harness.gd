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
	push_error("NETWORK CLIENT FAIL: " + message)
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
	if game.network_manager.join_host("127.0.0.1", TEST_PORT) != OK:
		fail("connection start")
		return
	game.online_mode = true
	game.online_is_host = false
	game.local_player_id = 2
	if not await wait_until(func(): return game.network_manager.multiplayer.has_multiplayer_peer() and game.network_manager.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED):
		fail("connection timeout")
		return
	game.network_manager.set_ready(true)
	if not await wait_until(func(): return game.state_machine.current == GameStateMachine.State.PIECE_PLACEMENT and game.board != null, 10.0):
		fail("client placement start")
		return
	game._confirm_placement()
	if not await wait_until(func(): return game.selection_player == 2 and not game.current_choices.is_empty(), 10.0):
		fail("client augment offer")
		return
	if selection_order == "host_first":
		await create_timer(0.55).timeout
	elif selection_order == "simultaneous":
		await create_timer(0.10).timeout
	var initial_choice: AugmentDefinition
	for definition in game.current_choices:
		if definition.id == &"wall_maria":
			initial_choice = definition
			break
	if initial_choice == null:
		fail("seeded wall maria offer missing")
		return
	game._choose_augment(initial_choice.id)
	if not await wait_until(func(): return game.board != null, 10.0):
		fail("world start timeout")
		return
	for round_index in 6:
		if not await wait_until(func(): return game.current_player == 2 and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, 12.0):
			fail("host shot snapshot timeout")
			return
		var client_piece: AlkkagiPiece
		for piece in game.get_pieces():
			if piece.owner_id == 2:
				client_piece = piece
				break
		if client_piece == null:
			fail("client piece missing")
			return
		if round_index == 0:
			var wall_effect: AugmentEffect
			for effect: AugmentEffect in game.augment_manager.effects[2]:
				if effect.definition.id == &"wall_maria":
					wall_effect = effect
					break
			if wall_effect == null:
				fail("wall maria effect missing after initial selection")
				return
			var wall_button: Button
			for candidate in game.hud.find_children("*", "Button", true, false):
				if candidate is Button and wall_effect.definition.display_name in candidate.text:
					wall_button = candidate
					break
			if wall_button == null:
				fail("wall maria active button missing")
				return
			wall_button.pressed.emit()
			await create_timer(0.15).timeout
			if game.state_machine.current != GameStateMachine.State.SKILL_TARGETING:
				fail("client skill targeting was overwritten by snapshots")
				return
			game.confirm_board_position_skill(Vector2.ZERO)
			if not await wait_until(func(): return game.hint_label != null and is_instance_valid(game.hint_label) and "요청 거절" in game.hint_label.text, 5.0):
				fail("invalid wall placement did not return a retry reason")
				return
			if game.state_machine.current != GameStateMachine.State.SKILL_TARGETING:
				fail("rejected wall request did not restore targeting")
				return
			game.confirm_board_position_skill(AlkkagiBoard.BOARD_RECT.get_center())
		else:
			game._on_piece_pressed(client_piece)
		if round_index == 1:
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			game._unhandled_input(escape)
			if game.state_machine.current != GameStateMachine.State.PLAYER_AIMING or game.round_count != 1:
				fail("client aim cancellation consumed action")
				return
			game._on_piece_pressed(client_piece)
		if round_index > 0:
			game.fire_selected(client_piece.global_position + Vector2(48, 0))
		if round_index not in [2, 5]:
			if not await wait_until(func(): return game.current_player == 1, 12.0):
				fail("client action result timeout")
				return
		else:
			if not await wait_until(func(): return game.state_machine.current == GameStateMachine.State.AUGMENT_SELECTION and game.selection_player == 2 and not game.current_choices.is_empty(), 12.0):
				fail("client reward offer")
				return
			game._choose_augment(game.current_choices[0].id)
			var expected_count := 2 if round_index == 2 else 3
			if not await wait_until(func(): return game.state_machine.current == GameStateMachine.State.PLAYER_AIMING and game.augment_manager.owned[1].size() == expected_count and game.augment_manager.owned[2].size() == expected_count, 10.0):
				fail("client reward selection completion")
				return
	if game.round_count != 6:
		fail("client shared sixth-round count mismatch")
		return
	print("PASS: ENet client snapshot and validated shot integration")
	game.network_manager.shutdown(false)
	quit(0)
