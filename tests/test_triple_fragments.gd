extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.clear_world()
	game.augment_manager.reset_match()
	game.reset_runtime_effects()
	game.start_game_world()
	await process_frame
	var shooter: AlkkagiPiece = game.get_pieces()[0]
	for piece: AlkkagiPiece in game.get_pieces():
		if piece != shooter:
			piece.queue_free()
	await process_frame
	var origin := AlkkagiBoard.BOARD_RECT.get_center()
	shooter.position = origin
	game.split_piece_and_launch(shooter, shooter.owner_id, Vector2(400, 0), 12.0)
	var pieces: Array = game.get_pieces()
	var starts: Array[Vector2] = []
	for piece: AlkkagiPiece in pieces:
		starts.append(piece.position)
	await physics_frame
	await physics_frame
	var velocities: Array[Vector2] = []
	for piece: AlkkagiPiece in pieces:
		velocities.append(piece.linear_velocity)
	for frame in 28:
		await physics_frame
	var first_distance: float = pieces[0].position.distance_to(starts[0])
	var last_distance: float = pieces[2].position.distance_to(starts[2])
	var ok := pieces.size() == 3 and is_equal_approx(pieces[0].mass, pieces[1].mass) and is_equal_approx(pieces[0].mass, pieces[2].mass)
	ok = ok and absf(velocities[0].length() - velocities[2].length()) < 0.1 and absf(first_distance - last_distance) < 0.1
	if ok:
		print("PASS: isolated triple fragments have symmetric mass, speed and travel")
	else:
		push_error("FAIL: triple fragment motion differs")
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)
