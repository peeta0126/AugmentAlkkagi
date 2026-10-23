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
	push_error("NETWORK CLIENT FAIL: " + message)
	if game and game.network_manager:
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
	if not await wait_until(func(): return game.network_manager.multiplayer.has_multiplayer_peer() and game.network_manager.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED):
		fail("connection timeout")
		return
	game.network_manager.set_ready(true)
	if not await wait_until(func(): return game.selection_player == 2 and not game.current_choices.is_empty(), 10.0):
		fail("client augment offer")
		return
	game._choose_augment(game.current_choices[0].id)
	if not await wait_until(func(): return game.board != null, 10.0):
		fail("world start timeout")
		return
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
	game._on_piece_pressed(client_piece)
	game.fire_selected(client_piece.global_position + Vector2(48, 0))
	if not await wait_until(func(): return game.current_player == 1, 12.0):
		fail("client shot result timeout")
		return
	print("PASS: ENet client snapshot and validated shot integration")
	game.network_manager.shutdown(false)
	quit(0)
