extends Node

var game: Node
var role := ""
var room_code := ""
var gameplay_test := false

func _ready() -> void:
	game = get_parent()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--gdsync-test-role="):
			role = argument.trim_prefix("--gdsync-test-role=")
		elif argument.begins_with("--room-code="):
			room_code = argument.trim_prefix("--room-code=")
		elif argument == "--gdsync-test-gameplay":
			gameplay_test = true
	call_deferred("run_test")

func wait_until(predicate: Callable, seconds: float = 15.0) -> bool:
	var elapsed := 0.0
	while elapsed < seconds:
		if predicate.call():
			return true
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05
	return false

func fail(message: String) -> void:
	push_error("GDSYNC LOBBY %s FAIL: %s" % [role.to_upper(), message])
	game.network_manager.shutdown(false)
	get_tree().quit(1)

func run_test() -> void:
	if room_code.length() != 6 or role not in ["host", "client"]:
		fail("invalid test arguments")
		return
	if not await wait_until(func(): return game.network_manager.gdsync_connected, 20.0):
		fail("server connection timeout")
		return
	if role == "host":
		await run_host()
	else:
		await run_client()

func run_host() -> void:
	if game.network_manager.create_online_room(room_code) != OK:
		fail("room creation request")
		return
	if not await wait_until(func(): return GDSync.lobby_get_name() == "AA-" + room_code, 15.0):
		fail("room creation timeout")
		return
	print("LOBBY_READY:", room_code)
	if not await wait_until(func(): return bool(game.network_manager.connected_players[2]), 20.0):
		fail("guest connection timeout")
		return
	if not await wait_until(func(): return GDSync.lobby_get_player_limit() == 2 and GDSync.lobby_get_player_count() == 2, 5.0):
		fail("lobby limit/count mismatch: %d/%d" % [GDSync.lobby_get_player_count(), GDSync.lobby_get_player_limit()])
		return
	if not await wait_until(func(): return bool(game.network_manager.ready_state[2]), 10.0):
		fail("guest ready timeout")
		return
	game.network_manager.set_ready(true)
	if not game.network_manager.can_start():
		fail("start conditions rejected")
		return
	print("PASS: GD-Sync host room, two-player limit, and ready state")
	if gameplay_test:
		await run_host_gameplay()
		return
	await get_tree().create_timer(1.0).timeout
	game.network_manager.shutdown(false)
	get_tree().quit(0)

func run_client() -> void:
	if game.network_manager.join_online_room(room_code) != OK:
		fail("room join request")
		return
	if not await wait_until(func(): return GDSync.lobby_get_name() == "AA-" + room_code and game.network_manager.gdsync_host_id >= 0, 15.0):
		fail("room join timeout")
		return
	game.network_manager.set_ready(true)
	if not await wait_until(func(): return bool(game.network_manager.ready_state[1]), 10.0):
		fail("host ready state timeout")
		return
	if game.network_manager.local_player_id != 2 or not bool(game.network_manager.connected_players[1]):
		fail("player assignment mismatch")
		return
	print("PASS: GD-Sync client joined by room code and synchronized ready state")
	if gameplay_test:
		await run_client_gameplay()
		return
	await get_tree().create_timer(1.0).timeout
	game.network_manager.shutdown(false)
	get_tree().quit(0)

func run_host_gameplay() -> void:
	game.augment_manager.rng.seed = 7
	if not game.network_manager.start_match():
		fail("game start rejected")
		return
	if not await wait_until(func(): return game.selection_player == 1 and not game.current_choices.is_empty(), 10.0):
		fail("host augment offer timeout")
		return
	if not await wait_until(func(): return bool(game.network_manager.selection_completed[2]), 10.0):
		fail("client augment choice timeout")
		return
	game._choose_augment(game.current_choices[0].id)
	if not await wait_until(func(): return game.board != null and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, 12.0):
		fail("world start timeout")
		return
	var host_piece: AlkkagiPiece
	for piece in game.get_pieces():
		if piece.owner_id == 1:
			host_piece = piece
			break
	game._on_piece_pressed(host_piece)
	game.fire_selected(host_piece.global_position + Vector2(48, 0))
	if not await wait_until(func(): return game.current_player == 2 and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, 12.0):
		fail("host shot did not advance turn")
		return
	if not await wait_until(func(): return game.current_player == 1 and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, 12.0):
		fail("client shot did not advance turn")
		return
	for piece in game.get_pieces():
		if piece.owner_id == 2:
			piece.position = AlkkagiBoard.BOARD_RECT.end + Vector2(200, 200)
	host_piece = null
	for piece in game.get_pieces():
		if piece.owner_id == 1:
			host_piece = piece
			break
	game._on_piece_pressed(host_piece)
	game.fire_selected(host_piece.global_position + Vector2(48, 0))
	if not await wait_until(func(): return game.state_machine.current == GameStateMachine.State.GAME_OVER and game.network_winner == 1, 12.0):
		fail("host victory resolution timeout")
		return
	print("PASS: GD-Sync host authoritative shot, turn, and victory flow")
	await get_tree().create_timer(3.0).timeout
	game.network_manager.shutdown(false)
	get_tree().quit(0)

func run_client_gameplay() -> void:
	if not await wait_until(func(): return game.selection_player == 2 and not game.current_choices.is_empty(), 12.0):
		fail("client augment offer timeout")
		return
	game._choose_augment(game.current_choices[0].id)
	if not await wait_until(func(): return game.board != null, 12.0):
		fail("client world start timeout")
		return
	if not await wait_until(func(): return game.current_player == 2 and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, 12.0):
		fail("host shot snapshot timeout")
		return
	var client_piece: AlkkagiPiece
	for piece in game.get_pieces():
		if piece.owner_id == 2:
			client_piece = piece
			break
	game._on_piece_pressed(client_piece)
	var pull_vector := Vector2(-48, 0)
	game.fire_selected(client_piece.global_position - pull_vector)
	GDSync.call_func_on(game.network_manager.gdsync_host_id, game.network_manager.request_shot, client_piece.piece_id, pull_vector, game.network_manager.local_sequence)
	if not await wait_until(func(): return game.current_player == 1, 12.0):
		fail("validated client shot result timeout")
		return
	if not await wait_until(func(): return game.state_machine.current == GameStateMachine.State.GAME_OVER and game.network_winner == 1, 15.0):
		fail("victory snapshot timeout")
		return
	print("PASS: GD-Sync client snapshot, duplicate-shot rejection, and game over")
	await get_tree().create_timer(1.0).timeout
	game.network_manager.shutdown(false)
	get_tree().quit(0)
