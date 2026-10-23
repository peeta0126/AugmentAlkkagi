extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

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
	game.start_game()
	await process_frame
	check(game.count_owner(1) == 3, "red pieces spawn from setting")
	check(game.count_owner(2) == 3, "blue pieces spawn from setting")
	check(game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, "game accepts aiming after start")

	var red_piece: AlkkagiPiece
	for piece in game.get_pieces():
		if piece.owner_id == 1:
			red_piece = piece
			break
	game._on_piece_pressed(red_piece)
	game.fire_selected(red_piece.global_position + Vector2(100, 0))
	await physics_frame
	check(game.state_machine.current == GameStateMachine.State.PIECES_MOVING, "valid shot enters moving state")
	check(red_piece.linear_velocity.x < 0.0, "piece moves opposite drag")

	for piece in game.get_pieces():
		if piece.owner_id == 2:
			piece.queue_free()
	await process_frame
	game.resolve_turn()
	check(game.state_machine.current == GameStateMachine.State.GAME_OVER, "eliminating a side ends the game")
	if failures == 0:
		print("PASS: Phase 1 scene integration tests")
	quit(failures)
