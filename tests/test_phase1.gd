extends SceneTree

var failures := 0

func _init() -> void:
	test_piece_count()
	test_shot_impulse()
	test_starting_positions()
	if failures == 0:
		print("PASS: Phase 1 gameplay rule tests")
	quit(failures)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func test_piece_count() -> void:
	check(GameplayRules.clamp_piece_count(1) == 3, "piece count lower bound")
	check(GameplayRules.clamp_piece_count(8) == 5, "piece count upper bound")
	check(GameplayRules.clamp_piece_count(4) == 4, "piece count keeps valid value")

func test_shot_impulse() -> void:
	var impulse := GameplayRules.shot_impulse(Vector2(100, 100), Vector2(50, 100))
	check(impulse.x > 0.0 and is_zero_approx(impulse.y), "shot travels opposite the drag")
	var maximum := GameplayRules.BALANCE.max_launch_impulse
	check(GameplayRules.shot_impulse(Vector2.ZERO, Vector2(1000, 0)).length() <= maximum + 0.01, "shot force is capped")

func test_starting_positions() -> void:
	var rect := Rect2(100, 100, 500, 500)
	var red := GameplayRules.starting_positions(rect, 1, 5)
	var blue := GameplayRules.starting_positions(rect, 2, 5)
	check(red.size() == 5 and blue.size() == 5, "requested pieces are placed")
	check(red[0].y < rect.get_center().y and blue[0].y > rect.get_center().y, "players spawn in opposite vertical territories")
