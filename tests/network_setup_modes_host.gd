extends SceneTree

const TEST_PORT := 7788
var game: Node

func _init() -> void:
	call_deferred("run_test")

func wait_until(predicate: Callable, seconds: float = 10.0) -> bool:
	var elapsed := 0.0
	while elapsed < seconds:
		if predicate.call():
			return true
		await create_timer(0.05).timeout
		elapsed += 0.05
	return false

func fail(message: String) -> void:
	push_error("NETWORK SETUP HOST FAIL: " + message)
	if game:
		game.network_manager.shutdown(false)
	quit(1)

func run_test() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	if game.network_manager.create_host(TEST_PORT) != OK:
		fail("server creation")
		return
	game.online_mode = true
	game.online_is_host = true
	game.local_player_id = 1
	game.network_manager.set_ready(true)
	if not await wait_until(func(): return bool(game.network_manager.connected_players[2]) and bool(game.network_manager.ready_state[2])):
		fail("guest connection and initial ready")
		return
	game.network_manager.set_modes(true, true)
	if bool(game.network_manager.ready_state[2]):
		fail("mode change did not clear guest ready")
		return
	if not await wait_until(func(): return bool(game.network_manager.ready_state[2])):
		fail("guest did not acknowledge synchronized modes")
		return
	if not game.network_manager.start_match():
		fail("match start")
		return
	if not await wait_until(func(): return game.state_machine.current == GameStateMachine.State.PIECE_PLACEMENT):
		fail("placement start")
		return
	game._confirm_placement()
	if not await wait_until(func(): return bool(game.network_manager.placement_completed[2])):
		fail("guest placement completion")
		return
	if not await wait_until(func(): return game.selection_player == 1 and game.selection_pick_target == 2 and not game.current_choices.is_empty()):
		fail("chaos offer")
		return
	game._refresh_augment_choices()
	if not bool(game.network_manager.selection_refresh_used[1]):
		fail("host refresh was not consumed")
		return
	game._choose_augment(game.current_choices[0].id)
	if game.selection_pick_index != 2 or not bool(game.network_manager.selection_refresh_used[1]):
		fail("refresh state did not persist into 2/2")
		return
	game._choose_augment(game.current_choices[0].id)
	if not await wait_until(func(): return game.state_machine.current == GameStateMachine.State.PLAYER_AIMING and game.augment_manager.owned[1].size() == 2 and game.augment_manager.owned[2].size() == 2):
		fail("two-pick selection completion")
		return
	print("PASS: ENet host placement and simultaneous refresh+chaos modes")
	await create_timer(1.0).timeout
	game.network_manager.shutdown(false)
	quit(0)
