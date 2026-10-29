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
	game.current_player = 1
	game.augment_manager.acquire(game, 1, &"greatsword")
	var sword: GreatswordAugmentEffect = game.augment_manager.effects[1][0]
	var knight: AlkkagiPiece = game.get_pieces().filter(func(p): return p.owner_id == 1)[0]
	var enemy: AlkkagiPiece = game.get_pieces().filter(func(p): return p.owner_id == 2)[0]
	sword.on_piece_target(game, 1, knight)
	game.state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
	game.selected_piece = knight
	game.fire_selected(knight.position - Vector2(60, 0))
	await physics_frame
	await physics_frame
	for p: AlkkagiPiece in game.get_pieces():
		p.stop_motion()
	knight.position = AlkkagiBoard.BOARD_RECT.get_center()
	enemy.position = knight.position + Vector2(50, 0)
	game.shot_elapsed = 1.0
	game.settle_time = 0.44
	game._physics_process(0.02)
	await physics_frame
	await physics_frame
	var restored := AlkkagiPiece.new()
	restored.setup(1, 98765)
	root.add_child(restored)
	restored.apply_compact_network_state(knight.compact_network_state(), 0, false)
	var ok: bool = enemy.linear_velocity.x > 0 and sword.cooldown_left == 3 and sword.pending_knight_id == -1 and restored.transformation == "KNIGHT"
	if ok:
		print("PASS: first knight shot triggers via game settling and knight visual state restores")
	else:
		push_error("FAIL: knight game resolution")
	restored.queue_free()
	game.queue_free()
	quit(0 if ok else 1)
