extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func run_test() -> void:
	# 실명 중에는 내 돌만 보이고 상대 돌은 숨겨진다.
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.clear_world()
	game.augment_manager.reset_match()
	game.reset_runtime_effects()
	game.start_game_world()
	game.blind_turns[1] = 1
	game.current_player = 1
	game.build_hud()
	await physics_frame
	await physics_frame
	for piece in game.get_pieces():
		check(piece.visible == (piece.owner_id == 1), "blinded player sees only own stones")
	game.blind_turns[1] = 0
	game.build_hud()
	await physics_frame
	await physics_frame
	for piece in game.get_pieces():
		check(piece.visible, "all stones are visible again after blindness ends")
	if failures == 0:
		print("PASS test_blind_sight")
	quit()
