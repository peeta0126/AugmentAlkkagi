extends SceneTree

const TEST_PORT := 7787
var game: Node

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
	if not game.network_manager.start_match():
		fail("match start rejected")
		return
	if not await wait_until(func(): return game.selection_player == 1 and not game.current_choices.is_empty()):
		fail("host augment offer")
		return
	game._choose_augment(game.current_choices[0].id)
	if not await wait_until(func(): return game.board != null, 10.0):
		fail("world start timeout")
		return
	if game.count_owner(1) != 5 or game.count_owner(2) != 5:
		fail("piece count mismatch")
		return
	var host_piece: AlkkagiPiece
	for piece in game.get_pieces():
		if piece.owner_id == 1:
			host_piece = piece
			break
	game._on_piece_pressed(host_piece)
	game.fire_selected(host_piece.global_position + Vector2(48, 0))
	if not await wait_until(func(): return game.current_player == 2 and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, 10.0):
		fail("host shot did not resolve")
		return
	if not await wait_until(func(): return game.current_player == 1 and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, 12.0):
		fail("client shot request did not resolve")
		return
	await create_timer(0.35).timeout
	print("PASS: ENet host authoritative localhost integration")
	game.network_manager.shutdown(false)
	quit(0)
