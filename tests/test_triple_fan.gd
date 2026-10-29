extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run_case(game: Node, forward: Vector2, size: float) -> void:
	game.clear_world()
	game.augment_manager.reset_match()
	game.reset_runtime_effects()
	game.start_game_world()
	await process_frame
	var source: AlkkagiPiece = game.get_pieces()[0]
	for p: AlkkagiPiece in game.get_pieces():
		if p != source:
			p.queue_free()
	await process_frame
	var origin := AlkkagiBoard.BOARD_RECT.get_center()
	source.position = origin
	source.tank_factor = size
	source.refresh_physics()
	game.split_piece_and_launch(source, 1, forward * 400.0, 12.0)
	var side := Vector2(-forward.y, forward.x)
	var pieces: Array = game.get_pieces()
	pieces.sort_custom(func(a, b): return a.position.dot(side) < b.position.dot(side))
	var starts: Array[Vector2] = []
	for p: AlkkagiPiece in pieces:
		starts.append(p.position)
	await physics_frame
	await physics_frame
	for i in 3:
		var p: AlkkagiPiece = pieces[i]
		var expected := forward.rotated(deg_to_rad((i - 1) * 12.0))
		check(p.linear_velocity.length() > 200, "fragment lost initial launch speed")
		check(p.linear_velocity.normalized().dot(expected) > 0.999, "fragment direction is not outward fan")
		check(absf(p.linear_velocity.length() - pieces[1].linear_velocity.length()) < 0.1, "fragment initial speeds differ")
		if i != 1:
			check((starts[i] - origin).dot(side) * p.linear_velocity.dot(side) > 0, "fragment converges toward center")
	for frame in 12:
		await physics_frame
	for i in 3:
		check(absf(pieces[i].position.distance_to(starts[i]) - pieces[1].position.distance_to(starts[1])) < 0.1, "fragment travel differs")
	check((pieces[2].position - pieces[0].position).dot(side) > (starts[2] - starts[0]).dot(side), "fan does not expand")

func run_test() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	for forward in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		for size in [0.9, 1.0, 1.5]:
			await run_case(game, forward, size)
	if failures == 0:
		print("PASS: outward fan vectors, initial speeds and travel in 4 directions and 3 sizes")
	game.queue_free()
	quit(failures)
