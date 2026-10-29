extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func reset(game: Node) -> void:
	game.clear_world()
	game.augment_manager.reset_match()
	game.reset_runtime_effects()
	game.start_game_world()
	game.current_player = 1
	game.state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
	await process_frame

func end_turn(game: Node) -> void:
	game.state_machine.transition(GameStateMachine.State.PIECES_MOVING)
	game.resolve_turn()

func run_test() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	for id in [&"snowball", &"greatsword", &"wall_maria", &"earthquake", &"wish"]:
		await reset(game)
		game.augment_manager.acquire(game, 1, id)
		var effect: AugmentEffect = game.augment_manager.effects[1][0]
		if id == &"greatsword":
			effect.on_piece_target(game, 1, game.get_pieces()[0])
		elif id == &"wall_maria":
			effect.on_position_target(game, 1, AlkkagiBoard.BOARD_RECT.get_center())
		elif id == &"snowball":
			effect.on_position_target(game, 1, game.player_center(1) + Vector2(200, 0))
		else:
			effect.activate_immediate(game, 1)
		check(game.current_player == 1 and game.state_machine.allows_aiming(), str(id) + " keeps aiming turn")
		if id == &"wall_maria" or id == &"earthquake":
			end_turn(game)
			check((not game.temporary_walls.is_empty()) if id == &"wall_maria" else effect.active, "field survives activation turn")
			end_turn(game)
			check((game.temporary_walls[0].turns_left == 1) if id == &"wall_maria" else effect.turns_left == 1, "first return completes one cycle")
			end_turn(game)
			end_turn(game)
			check(game.temporary_walls.is_empty() if id == &"wall_maria" else not effect.active, "second return removes field")
		else:
			game.selected_piece = game.get_pieces()[0]
			game.fire_selected(game.selected_piece.position - Vector2(60, 0))
			check(game.state_machine.current == GameStateMachine.State.PIECES_MOVING, "normal shot remains available")
	await reset(game)
	game.augment_manager.acquire(game, 1, &"stasis")
	game.augment_manager.effects[1][0].activate_immediate(game, 1)
	var stone: AlkkagiPiece = game.get_pieces()[0]
	stone.tick_status(1)
	check(stone.stasis_turns == 2, "activation end does not consume a cycle")
	end_turn(game)
	check(stone.stasis_turns == 2, "opponent turn starts without decrement")
	end_turn(game)
	check(stone.stasis_turns == 1 and stone.freeze and stone.invulnerable, "first owner return keeps freeze")
	end_turn(game)
	end_turn(game)
	check(not stone.freeze and not stone.invulnerable, "freeze expires")
	await reset(game)
	game.augment_manager.acquire(game, 1, &"blind")
	game.augment_manager.effects[1][0].activate_immediate(game, 1)
	game.online_mode = true
	game.local_player_id = 2
	game.update_piece_visibility()
	for p: AlkkagiPiece in game.get_pieces():
		check(p.modulate.a == 1.0 and p.collision_layer == 1, "sight mask handles stones without permanently hiding enemies")
	game.build_hud()
	game._update_blind_centers()
	check(game.blind_material != null, "blinded viewer receives sight mask even during opponent turn")
	var sight_centers: PackedVector2Array = game.blind_material.get_shader_parameter("centers")
	check(sight_centers.size() == game.count_owner(2), "each own stone creates a sight circle")
	for center in sight_centers:
		var world_center := center * AlkkagiBoard.BOARD_RECT.size + AlkkagiBoard.BOARD_RECT.position
		check(game.get_pieces().any(func(p): return p.owner_id == 2 and p.position.distance_to(world_center) < 0.01), "sight circles follow viewer stones only")
	check((game.blind_material.get_shader_parameter("veil_color") as Color).a == 1.0, "outside sight is fully opaque")
	game.local_player_id = 1
	game.update_piece_visibility()
	check(game.get_pieces()[0].modulate.a == 1, "caster renders normally")
	game.online_mode = false
	end_turn(game)
	check(game.blind_turns[2] == 2, "caster turn does not tick blind")
	end_turn(game)
	check(game.blind_turns[2] == 1, "first target turn")
	end_turn(game)
	end_turn(game)
	game.update_piece_visibility()
	check(game.blind_turns[2] == 0 and game.get_pieces()[0].modulate.a == 1, "second target turn restores rendering")
	if failures == 0:
		print("PASS: seven augment patch and actual turn transitions")
	game.queue_free()
	quit(failures)
