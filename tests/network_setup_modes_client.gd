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
	push_error("NETWORK SETUP CLIENT FAIL: " + message)
	if game:
		game.network_manager.shutdown(false)
	quit(1)

func run_test() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	if game.network_manager.join_host("127.0.0.1", TEST_PORT) != OK:
		fail("connection start")
		return
	game.online_mode = true
	game.online_is_host = false
	game.local_player_id = 2
	if not await wait_until(func(): return game.network_manager.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED):
		fail("connection")
		return
	game.network_manager.set_ready(true)
	if not await wait_until(func(): return game.network_manager.refresh_mode and game.network_manager.chaos_mode):
		fail("mode synchronization")
		return
	game.network_manager.set_ready(true)
	if not await wait_until(func(): return game.state_machine.current == GameStateMachine.State.PIECE_PLACEMENT and game.board != null):
		fail("placement start")
		return
	var piece := game.find_piece(200) as AlkkagiPiece
	var requested_position := piece.position + Vector2(18.0, 0.0)
	game.network_manager.submit_piece_placement(piece.piece_id, requested_position)
	if not await wait_until(func(): return piece.position.distance_to(requested_position) < 0.1):
		fail("host-approved placement coordinate")
		return
	game._confirm_placement()
	if not await wait_until(func(): return game.selection_player == 2 and game.selection_pick_target == 2 and not game.current_choices.is_empty()):
		fail("chaos offer")
		return
	game._refresh_augment_choices()
	if not await wait_until(func(): return game.selection_refresh_used):
		fail("refresh confirmation")
		return
	game._choose_augment(game.current_choices[0].id)
	if not await wait_until(func(): return game.selection_pick_index == 2 and not game.current_choices.is_empty()):
		fail("second chaos offer")
		return
	if not game.selection_refresh_used:
		fail("refresh state was reset between picks")
		return
	game._choose_augment(game.current_choices[0].id)
	if not await wait_until(func(): return game.state_machine.current == GameStateMachine.State.PLAYER_AIMING and game.augment_manager.owned[1].size() == 2 and game.augment_manager.owned[2].size() == 2):
		fail("two-pick completion")
		return
	print("PASS: ENet guest authoritative placement and simultaneous refresh+chaos modes")
	await create_timer(1.0).timeout
	game.network_manager.shutdown(false)
	quit(0)
