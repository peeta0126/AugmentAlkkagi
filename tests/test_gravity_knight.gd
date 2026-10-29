extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func reset_game(game: Node) -> void:
	game.clear_world()
	game.augment_manager.reset_match()
	game.reset_runtime_effects()
	game.start_game_world()
	game.current_player = 1
	game.state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
	await process_frame

func run_test() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"gravity_field")
	var gravity: GravityFieldAugmentEffect = game.augment_manager.effects[1][0]
	var allies: Array = game.get_pieces().filter(func(p): return p.owner_id == 1)
	var enemies: Array = game.get_pieces().filter(func(p): return p.owner_id == 2)
	var center := AlkkagiBoard.BOARD_RECT.get_center()
	allies[0].position = center + Vector2(100, 0)
	allies[1].position = center + Vector2(0, 100)
	enemies[0].position = center + Vector2(-100, 0)
	enemies[1].position = center + Vector2(205, 0)
	check(not gravity.on_position_target(game, 1, Vector2(-1, -1)) and gravity.uses_left == 1, "invalid placement is not consumed")
	check(gravity.on_position_target(game, 1, center), "valid placement")
	check(game.state_machine.current == GameStateMachine.State.PLAYER_AIMING and gravity.has_center and not gravity.active, "placement does not consume turn or activate")
	check(game.board.field_visuals.has("gravity_1") and gravity.uses_left == 0, "waiting field visible and one use consumed")
	gravity.on_physics_tick(game, 1, 0.1)
	check(allies[0].linear_velocity.is_zero_approx() and enemies[0].linear_velocity.is_zero_approx(), "waiting field applies no force")
	check(not gravity.on_position_target(game, 1, center), "cannot install twice")
	game.selected_piece = allies[0]
	game.fire_selected(allies[0].global_position)
	check(gravity.has_center and not gravity.active, "invalid shot does not consume field")
	gravity.after_shot(game, 2, enemies[0])
	check(gravity.has_center and not gravity.active, "opponent shot does not activate field")
	game.selected_piece = allies[0]
	game.fire_selected(allies[0].global_position - Vector2(50, 0))
	check(gravity.active and not gravity.has_center and game.board.field_visuals.has("gravity_1"), "valid own shot activates installed field")
	gravity.on_physics_tick(game, 1, 0.1)
	await physics_frame
	check(enemies[0].linear_velocity.x > 0, "gravity attracts enemy toward center")
	check(allies[1].linear_velocity.y < 0, "gravity attracts ally toward center")
	check(enemies[1].linear_velocity.is_zero_approx(), "gravity excludes stones beyond 200 pixels")
	gravity.on_physics_tick(game, 1, 2.0)
	check(not gravity.active and not game.board.field_visuals.has("gravity_1"), "gravity expires and clears visual")
	gravity.after_shot(game, 1, allies[0])
	check(not gravity.active and not gravity.has_center, "subsequent shot cannot reactivate gravity")

	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"greatsword")
	var sword: GreatswordAugmentEffect = game.augment_manager.effects[1][0]
	allies = game.get_pieces().filter(func(p): return p.owner_id == 1)
	enemies = game.get_pieces().filter(func(p): return p.owner_id == 2)
	var knight: AlkkagiPiece = allies[0]
	var other: AlkkagiPiece = allies[1]
	var enemy: AlkkagiPiece = enemies[0]
	knight.position = center
	other.position = center + Vector2(0, 50)
	enemy.position = center + Vector2(50, 0)
	check(sword.on_piece_target(game, 1, knight) and sword.cooldown_left == 0 and knight.transformation == "KNIGHT", "designation transforms knight and leaves first attack ready")
	check(not sword.on_piece_target(game, 1, other), "only one knight can be designated")
	check(sword.definition.cooldown_turns == 0, "knight has no cooldown")
	game.state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
	game.selected_piece = other
	game.fire_selected(other.global_position - Vector2(50, 0))
	knight.linear_velocity = Vector2(80, 0)
	check(sword.pending_knight_id == -1 and not sword.on_pieces_settled(game, 1) and sword.cooldown_left == 0, "other shot and indirect knight movement do not trigger or consume cooldown")
	knight.linear_velocity = Vector2.ZERO
	game.state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
	game.selected_piece = knight
	game.fire_selected(knight.global_position - Vector2(50, 0))
	check(sword.pending_knight_id == knight.piece_id, "direct knight shot is recorded")
	other.stop_motion()
	check(sword.on_pieces_settled(game, 1) and sword.cooldown_left == 0, "direct knight shot triggers without cooldown")
	check(not sword.on_pieces_settled(game, 1), "one activation per shot")
	await physics_frame
	check(enemy.linear_velocity.x > 0, "knight pushes enemy outward")
	check(other.linear_velocity.is_zero_approx(), "knight does not push allies")
	check(sword.network_state().pending_knight_id == -1, "consumed shot state is serialized")
	sword.after_shot(game, 1, knight)
	check(sword.on_pieces_settled(game, 1), "next direct shot can trigger immediately")
	sword.cooldown_left = 0
	sword.after_shot(game, 1, knight)
	knight.queue_free()
	check(not sword.on_pieces_settled(game, 1) and sword.cooldown_left == 0, "removed knight cannot trigger or consume cooldown")
	if failures == 0:
		print("PASS: gravity one-shot and direct knight shot")
	game.queue_free()
	quit(failures)
