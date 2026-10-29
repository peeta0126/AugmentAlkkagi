extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func run_test() -> void:
	# 돌을 숨기지 않고 자기 돌 중심 시야 셰이더로 가린다.
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
		check(piece.visible and piece.modulate.a == 1.0, "enemy stones remain renderable inside sight")
	check(game.blind_material != null, "blind sight mask exists")
	var centers: PackedVector2Array = game.blind_material.get_shader_parameter("centers")
	check(centers.size() == game.count_owner(1), "sight follows each own stone")
	check(float(game.blind_material.get_shader_parameter("sight_radius")) == 82.0, "latest sight radius is preserved")
	check((game.blind_material.get_shader_parameter("veil_color") as Color).a == 1.0, "outside sight is opaque")
	game.blind_turns[1] = 0
	game.build_hud()
	await physics_frame
	await physics_frame
	for piece in game.get_pieces():
		check(piece.visible, "all stones are visible again after blindness ends")
	if failures == 0:
		print("PASS test_blind_sight")
	quit(failures)
