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
	var starting_round: int = game.round_count
	game._on_piece_pressed(red_piece)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._unhandled_input(escape)
	check(not game.dragging and game.selected_piece == null, "escape cancels aiming")
	check(game.current_player == 1 and game.round_count == starting_round, "escape cancellation consumes no turn or round")
	var left_release := InputEventMouseButton.new()
	left_release.button_index = MOUSE_BUTTON_LEFT
	left_release.pressed = false
	game._unhandled_input(left_release)
	check(game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, "left release after cancellation does not fire")

	game._on_piece_pressed(red_piece)
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	game._unhandled_input(right_click)
	check(not game.dragging and game.selected_piece == null, "right click cancels aiming")

	game._on_piece_pressed(red_piece)
	game.fire_selected(red_piece.global_position + Vector2(GameplayRules.MIN_SHOT_DRAG_DISTANCE - 1.0, 0))
	check(game.state_machine.current == GameStateMachine.State.PLAYER_AIMING and game.current_player == 1, "short drag does not fire or consume turn")

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
