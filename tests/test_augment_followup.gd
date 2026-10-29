extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func reset_game(game: Node) -> void:
	game.clear_world()
	game.augment_manager.reset_match()
	game.reset_runtime_effects()
	game.start_game_world()
	game.current_player = 1
	await process_frame

func run_test() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"greatsword")
	var sword: GreatswordAugmentEffect = game.augment_manager.effects[1][0]
	var own: AlkkagiPiece = game.get_pieces().filter(func(p): return p.owner_id == 1)[0]
	var enemy: AlkkagiPiece = game.get_pieces().filter(func(p): return p.owner_id == 2)[0]
	var friend: AlkkagiPiece = game.get_pieces().filter(func(p): return p.owner_id == 1)[1]
	own.position = Vector2(620, 350)
	enemy.position = own.position + Vector2(50, 0)
	friend.position = own.position + Vector2(0, 50)
	check(sword.on_piece_target(game, 1, own), "knight designation")
	check(enemy.linear_velocity.is_zero_approx(), "designation does not immediately push")
	sword.cooldown_left = 0
	sword.after_shot(game, 1, own)
	check(sword.on_pieces_settled(game, 1), "knight pushes after settling")
	check(not sword.on_pieces_settled(game, 1), "knight triggers once")
	await physics_frame
	check(enemy.linear_velocity.x > 0 and friend.linear_velocity.is_zero_approx(), "knight pushes only enemies outward")
	check(sword.network_state().knight_ids.has(own.piece_id), "knight id included in snapshot")
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"king")
	var king: KingAugmentEffect = game.augment_manager.effects[1][0]
	var allies: Array = game.get_pieces().filter(func(p): return p.owner_id == 1)
	allies[0].position.y = AlkkagiBoard.BOARD_RECT.end.y - 10
	allies[1].position.y = AlkkagiBoard.BOARD_RECT.end.y - 10
	king.on_physics_tick(game, 1, 0.016)
	check(allies[0].transformation == "KING" and allies[1].transformation != "KING", "king transforms once on reaching enemy edge")
	allies[0].queue_free()
	await process_frame
	king.on_physics_tick(game, 1, 0.016)
	check(allies[1].transformation != "KING" and king.network_state().transformed_once, "king limit persists after removal")
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"wizard")
	var wizard: WizardAugmentEffect = game.augment_manager.effects[1][0]
	allies = game.get_pieces().filter(func(p): return p.owner_id == 1)
	wizard.on_piece_target(game, 1, allies[0])
	wizard.cancel_active()
	wizard.on_piece_target(game, 1, allies[1])
	check(wizard.designated_id == allies[0].piece_id and allies[1].transformation != "WIZARD", "wizard cannot designate a second piece")
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"stealth")
	var hidden: AlkkagiPiece = game.get_pieces().filter(func(p): return p.owner_id == 1)[0]
	game.augment_manager.effects[1][0].on_piece_target(game, 1, hidden)
	game.augment_manager.start_player_turn(game, 2)
	check(hidden.stealth_turns == 2, "stealth does not tick at opponent turn start")
	game.augment_manager.start_player_turn(game, 1)
	check(hidden.stealth_turns == 1, "stealth lasts after first return")
	game.augment_manager.start_player_turn(game, 1)
	check(hidden.hidden_from_player == 0, "stealth expires at second return")
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"stasis")
	var frozen: AlkkagiPiece = game.get_pieces().filter(func(p): return p.owner_id == 1)[0]
	game.augment_manager.effects[1][0].activate_immediate(game, 1)
	frozen.apply_snow(3)
	frozen.tick_status(1)
	frozen.tick_status(1)
	check(frozen.freeze and not frozen.invulnerable and frozen.snow_turns == 1, "time freeze expires without clearing snow")
	frozen.tick_status(1)
	check(not frozen.freeze, "snow eventually expires")
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"gravity_field")
	var gravity: GravityFieldAugmentEffect = game.augment_manager.effects[1][0]
	var center := AlkkagiBoard.BOARD_RECT.get_center()
	check(gravity.on_position_target(game, 1, center), "gravity center selection")
	check(not gravity.definition.consumes_turn, "gravity targeting does not consume turn")
	gravity.after_shot(game, 1, game.get_pieces()[0])
	check(gravity.active and gravity.center_position == center, "gravity triggers on shot at chosen point")
	check(is_equal_approx(float(gravity.definition.values.radius), 200.0), "gravity radius is 200")
	check(is_equal_approx(float(game.augment_manager.get_definition(&"dodge").values.chance), 0.4), "dodge probability is 40 percent")
	if failures == 0:
		print("PASS: augment followup")
	game.queue_free()
	quit(failures)
