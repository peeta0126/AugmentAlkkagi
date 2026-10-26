extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func shoot_and_resolve(game: Node, player_id: int) -> void:
	var piece: AlkkagiPiece
	for candidate: AlkkagiPiece in game.get_pieces():
		if candidate.owner_id == player_id:
			piece = candidate
			break
	if piece == null:
		check(false, "player %d has a playable stone" % player_id)
		return
	game._on_piece_pressed(piece)
	game.fire_selected(piece.global_position + Vector2(110.0, 0.0))
	check(game.state_machine.current == GameStateMachine.State.PIECES_MOVING, "player %d shot enters moving state" % player_id)
	for moving_piece: AlkkagiPiece in game.get_pieces():
		moving_piece.linear_velocity = Vector2.ZERO
	game.resolve_turn()

func run_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	check(packed != null, "main scene loads")
	if packed == null:
		quit(failures)
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.starting_piece_count = 3
	game._start_developer_mode()
	await process_frame
	check(game.state_machine.current == GameStateMachine.State.INITIAL_AUGMENT_SELECTION, "developer mode opens augment selection")
	check(game.screen_root.grid.get_child_count() == game.augment_manager.CATALOG.size(), "developer mode lists every enabled augment")
	game._on_developer_augment_selected(&"tank")
	await process_frame
	check(game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, "selecting an augment starts a playable game")
	check(game.augment_manager.has_augment(1, &"tank") and game.augment_manager.has_augment(2, &"tank"), "selected augment is granted to black and white")
	check(game.count_owner(1) == 3 and game.count_owner(2) == 3, "both sides receive playable stones")
	shoot_and_resolve(game, 1)
	check(game.current_player == 2 and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, "turn passes to white after black shoots")
	shoot_and_resolve(game, 2)
	check(game.current_player == 1 and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, "turn passes back to black after white shoots")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: developer selection, mirrored augment, and playable black/white turns")
	quit(failures)