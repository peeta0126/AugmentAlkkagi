extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run_test() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.clear_world()
	game.augment_manager.reset_match()
	game.reset_runtime_effects()
	game.start_game_world()
	await process_frame
	game.current_player = 1
	for id in [&"connect_four", &"lantern", &"marksman"]:
		check(game.augment_manager.get_definition(id) == null, "removed augment is still selectable")
	game.augment_manager.acquire(game, 1, &"blizzard")
	var blizzard: BlizzardAugmentEffect = game.augment_manager.effects[1].back()
	game.augment_manager.start_player_turn(game, 1)
	game.augment_manager.start_player_turn(game, 1)
	check(blizzard.cycles_left == 1 and game.blizzard_turns != 0, "blizzard expired early")
	game.augment_manager.start_player_turn(game, 1)
	check(game.blizzard_turns == 0, "blizzard did not expire")
	game.augment_manager.acquire(game, 1, &"stasis")
	var stasis: StasisAugmentEffect = game.augment_manager.effects[1].back()
	stasis.activate_immediate(game, 1)
	for piece: AlkkagiPiece in game.get_pieces():
		check((piece.freeze and piece.invulnerable) if piece.owner_id == 1 else not piece.invulnerable, "time freeze affected the wrong pieces")
	game.augment_manager.acquire(game, 1, &"gravity_field")
	var gravity: GravityFieldAugmentEffect = game.augment_manager.effects[1].back()
	check(not gravity.on_position_target(game, 1, Vector2(-1000, -1000)), "gravity accepted an invalid position")
	check(gravity.on_position_target(game, 1, AlkkagiBoard.BOARD_RECT.get_center()), "gravity rejected a valid position")
	check(gravity.center_position == AlkkagiBoard.BOARD_RECT.get_center(), "gravity used the wrong center")
	if failures == 0:
		print("PASS: augment patch")
	game.queue_free()
	quit(1 if failures else 0)
