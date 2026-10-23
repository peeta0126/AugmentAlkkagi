extends SceneTree

var failures := 0

func _init() -> void:
	test_board_dimensions()
	test_grid_and_star_points()
	test_stone_dimensions()
	test_starting_layouts()
	if failures == 0:
		print("PASS: physical board and stone geometry tests")
	quit(failures)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func close_enough(actual: float, expected: float, message: String) -> void:
	check(absf(actual - expected) < 0.001, message)

func test_board_dimensions() -> void:
	close_enough(AlkkagiBoard.BOARD_RECT.size.x, 504.0, "board width is 504px")
	close_enough(AlkkagiBoard.BOARD_RECT.size.y, 540.0, "board height is 540px")
	close_enough(AlkkagiBoard.BOARD_RECT.size.x / AlkkagiBoard.BOARD_RECT.size.y, 14.0 / 15.0, "board ratio is 14:15")
	check(AlkkagiBoard.BOARD_RECT.has_point(AlkkagiBoard.BOARD_RECT.get_center()), "board center is inside boundary")
	check(not AlkkagiBoard.BOARD_RECT.has_point(AlkkagiBoard.BOARD_RECT.position - Vector2.ONE), "outside point is rejected")

func test_grid_and_star_points() -> void:
	check(AlkkagiBoard.GRID_COUNT == 19, "grid has 19 horizontal and vertical lines")
	check(AlkkagiBoard.STAR_INDICES.size() * AlkkagiBoard.STAR_INDICES.size() == 9, "grid has nine star points")
	var board := AlkkagiBoard.new()
	var upper_left := board.grid_point(0, 0)
	var lower_right := board.grid_point(18, 18)
	check(upper_left.is_equal_approx(AlkkagiBoard.GRID_RECT.position), "first grid point matches inner margin")
	check(lower_right.is_equal_approx(AlkkagiBoard.GRID_RECT.end), "last grid point matches inner margin")
	board.free()

func test_stone_dimensions() -> void:
	close_enough(AlkkagiPiece.BLACK_RADIUS * 2.0, 26.64, "black stone diameter follows 22.2mm conversion")
	close_enough(AlkkagiPiece.WHITE_RADIUS * 2.0, 26.28, "white stone diameter follows 21.9mm conversion")
	var black := AlkkagiPiece.new()
	black.setup(1, 1)
	var white := AlkkagiPiece.new()
	white.setup(2, 2)
	close_enough((black.collision_shape.shape as CircleShape2D).radius, black.visual_radius, "black collider matches visual radius")
	close_enough((white.collision_shape.shape as CircleShape2D).radius, white.visual_radius, "white collider matches visual radius")
	black.free()
	white.free()

func test_starting_layouts() -> void:
	for count in [3, 4, 5]:
		var black := GameplayRules.starting_positions(AlkkagiBoard.BOARD_RECT, 1, count)
		var white := GameplayRules.starting_positions(AlkkagiBoard.BOARD_RECT, 2, count)
		check(black.size() == count and white.size() == count, "%d-piece layout has correct count" % count)
		for positions in [black, white]:
			for index in positions.size():
				check(AlkkagiBoard.BOARD_RECT.has_point(positions[index]), "spawn stays inside board")
				for other in range(index + 1, positions.size()):
					check(positions[index].distance_to(positions[other]) > AlkkagiPiece.BLACK_DIAMETER * 1.25, "spawned stones do not overlap")
		check(black[0].y < AlkkagiBoard.BOARD_RECT.get_center().y and white[0].y > AlkkagiBoard.BOARD_RECT.get_center().y, "players use top and bottom territories")
