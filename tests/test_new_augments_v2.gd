extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func find_effect(game: Node, player_id: int, augment_id: StringName) -> AugmentEffect:
	for effect: AugmentEffect in game.augment_manager.effects[player_id]:
		if effect.definition.id == augment_id:
			return effect
	return null

func pieces_for(game: Node, player_id: int) -> Array[AlkkagiPiece]:
	var result: Array[AlkkagiPiece] = []
	for piece: AlkkagiPiece in game.get_pieces():
		if piece.owner_id == player_id:
			result.append(piece)
	return result

func reset_game(game: Node) -> void:
	game.clear_world()
	game.augment_manager.reset_match()
	game.reset_runtime_effects()
	game.start_game_world()
	await process_frame

func run_test() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame

	# 피의 축제: 일반 발사의 처치만 한 차례 보너스 턴을 만들며 승리가 우선한다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"blood_festival")
	game.shot_opponent_count_before = game.count_owner(2)
	pieces_for(game, 2)[0].queue_free()
	await process_frame
	game.state_machine.transition(GameStateMachine.State.PIECES_MOVING)
	game.resolve_turn()
	check(game.current_player == 1 and game.bonus_turn_active and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, "blood festival grants one bonus shot after an enemy ring-out")
	game.shot_opponent_count_before = game.count_owner(2)
	game.state_machine.transition(GameStateMachine.State.PIECES_MOVING)
	game.resolve_turn()
	check(game.current_player == 2 and not game.bonus_turn_active, "blood festival bonus shot cannot chain without a new normal turn")

	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"blood_festival")
	game.shot_opponent_count_before = game.count_owner(2)
	for piece in pieces_for(game, 2):
		piece.queue_free()
	await process_frame
	game.state_machine.transition(GameStateMachine.State.PIECES_MOVING)
	game.resolve_turn()
	check(game.state_machine.current == GameStateMachine.State.GAME_OVER and game.network_winner == 1 and not game.bonus_turn_active, "victory takes priority over blood festival")

	# 중력장: 발사 돌 주변의 양 팀 돌을 호스트 물리로 끌어당긴다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"gravity_field")
	var gravity: GravityFieldAugmentEffect = find_effect(game, 1, &"gravity_field")
	var own := pieces_for(game, 1)
	var enemies := pieces_for(game, 2)
	own[0].position = AlkkagiBoard.BOARD_RECT.get_center()
	own[1].position = own[0].position + Vector2(70, 0)
	enemies[0].position = own[0].position + Vector2(-70, 0)
	gravity.after_shot(game, 1, own[0])
	gravity.on_physics_tick(game, 1, 0.016)
	await physics_frame
	check(own[1].linear_velocity.x < 0.0 and enemies[0].linear_velocity.x > 0.0, "gravity field attracts allied and enemy stones (ally=%s enemy=%s)" % [own[1].linear_velocity, enemies[0].linear_velocity])
	check(game.board.field_visuals.has("gravity_1"), "gravity field has a synchronized circular visual")

	# 은신: 상대 화면에서만 감추고 상대 턴 종료 후 복원한다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"stealth")
	var hidden_piece := pieces_for(game, 1)[0]
	var stealth: StealthAugmentEffect = find_effect(game, 1, &"stealth")
	check(stealth.on_piece_target(game, 1, hidden_piece), "stealth accepts one allied target")
	game.online_mode = true
	game.local_player_id = 2
	game.update_piece_visibility()
	check(not hidden_piece.visible, "stealthed stone is hidden from the opponent")
	game.local_player_id = 1
	game.update_piece_visibility()
	check(hidden_piece.visible, "stealthed stone remains visible to its owner")
	hidden_piece.tick_stealth(2)
	game.local_player_id = 2
	game.update_piece_visibility()
	check(hidden_piece.visible and hidden_piece.hidden_from_player == 0, "stealth ends after the opponent's next turn")
	game.online_mode = false

	# 지진: 초기 돌과 겹치지 않는 균열을 만들고 진입한 돌만 제거한다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"earthquake")
	var earthquake: EarthquakeAugmentEffect = find_effect(game, 1, &"earthquake")
	earthquake.activate_immediate(game, 1)
	check(earthquake.active and earthquake.cracks.size() == 3, "earthquake creates the configured number of safe cracks")
	var cracked_piece := pieces_for(game, 2)[0]
	cracked_piece.position = earthquake.cracks[0].from.lerp(earthquake.cracks[0].to, 0.5)
	earthquake.activation_delay = 0.0
	earthquake.on_physics_tick(game, 1, 0.016)
	await process_frame
	check(not is_instance_valid(cracked_piece), "stone entering an active crack is eliminated")
	check(game.board.field_visuals.has("earthquake_1"), "earthquake cracks remain visible")

	# 소원: 겹치지 않는 일곱 구슬, 수집 UI 상태, 특수 승리를 검증한다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"wish")
	var wish: WishAugmentEffect = find_effect(game, 1, &"wish")
	wish.activate_immediate(game, 1)
	check(wish.active and wish.balls.size() == 7 and wish.status_text() == "0/7 수집", "wish places seven distinct dragon balls and reports 0/7")
	var collector := pieces_for(game, 1)[0]
	while not wish.balls.is_empty():
		collector.position = wish.balls[0].position
		wish.on_physics_tick(game, 1, 0.016)
	check(wish.collected == 7 and wish.check_special_victory(game, 1), "collecting all seven dragon balls grants special victory")
	check(wish.status_text() == "7/7 수집", "wish UI reports 7/7")

	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: all five version 2 augments")
	quit(failures)
