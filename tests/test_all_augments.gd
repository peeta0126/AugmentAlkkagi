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

func first_piece(game: Node, player_id: int) -> AlkkagiPiece:
	for piece in game.get_pieces():
		if piece.owner_id == player_id:
			return piece
	return null

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
	check(game.augment_manager.CATALOG.size() == 20, "catalog registers all 20 augments")
	var ids := {}
	for definition in game.augment_manager.CATALOG:
		ids[definition.id] = true
	check(ids.size() == 20, "all augment IDs are unique")
	game.augment_manager.reset_match()
	for definition in game.augment_manager.CATALOG:
		check(game.augment_manager.acquire(game, 1, definition.id), "acquire succeeds for %s" % definition.id)
	check(game.augment_manager.owned[1].size() == 20, "one player can independently own all 20 unique augments")
	game.augment_manager.reset_match()

	# 01 삼연발: 원본 하나가 물리 충돌을 가진 소형 돌 셋으로 교체된다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"triple_shot")
	game.augment_manager.acquire(game, 1, &"sonic_boom")
	var original := first_piece(game, 1)
	var before_count: int = game.count_owner(1)
	find_effect(game, 1, &"triple_shot").transform_shot(game, 1, original, Vector2(400, 0))
	await process_frame
	check(game.count_owner(1) == before_count + 2, "triple shot replaces one stone with three")
	var fragment_count := 0
	for piece in game.get_pieces():
		if piece.owner_id == 1 and piece.fragment_factor < 1.0:
			fragment_count += 1
	check(fragment_count == 3, "triple shot creates three physical fragments")
	for piece in game.get_pieces():
		if piece.owner_id == 1 and piece.fragment_factor < 1.0:
			check(piece.sonic_trail, "triple-shot fragments inherit sonic trail")

	# 02 존야: 실제 스킬 선택 상태, 동결, 무적, 지속 종료를 검증한다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"stasis")
	var stasis := find_effect(game, 1, &"stasis")
	stasis.begin_active(game, 1)
	check(game.state_machine.current == GameStateMachine.State.SKILL_TARGETING, "active skill enters targeting state")
	var black := first_piece(game, 1)
	game._on_piece_pressed(black)
	check(black.freeze and black.invulnerable, "stasis freezes and protects its target")
	black.tick_status(1)
	check(black.freeze and black.invulnerable, "stasis remains through the activation turn")
	black.tick_status(1)
	check(not black.freeze and not black.invulnerable, "stasis ends and restores the stone")

	# 03 느려: 예측 선상 아군이 옆으로 이동한다.
	await reset_game(game)
	var dodger := first_piece(game, 1)
	dodger.position = Vector2(640, 360)
	var dodge_before := dodger.position
	check(game.try_dodge(1, Vector2(440, 360), Vector2.RIGHT, 1.0, 34.0), "dodge triggers on a predicted collision")
	check(not dodger.position.is_equal_approx(dodge_before), "dodge moves the threatened stone")

	# 04 장기: 일곱 후보 중 하나로 변신하고 실제 물리 표식을 가진다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"janggi")
	black = first_piece(game, 1)
	find_effect(game, 1, &"janggi").on_piece_target(game, 1, black)
	check(black.transformation in JanggiAugmentEffect.PIECES, "janggi assigns a supported piece type")

	# 05 업기: 두 돌을 한 스택으로 합치고 질량/외형을 변경한다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"piggyback")
	game.augment_manager.acquire(game, 1, &"tank")
	var own: Array[AlkkagiPiece] = []
	for piece in game.get_pieces():
		if piece.owner_id == 1:
			own.append(piece)
	var piggy := find_effect(game, 1, &"piggyback")
	piggy.on_piece_target(game, 1, own[0])
	piggy.on_piece_target(game, 1, own[1])
	await process_frame
	check(own[0].carried_count == 1 and own[0].mass > 1.8, "piggyback and tank create a heavier visible stack")
	check(game.count_owner(1) == GameplayRules.DEFAULT_PIECES - 1, "piggyback merges the carried stone")

	# 06 랜턴: 두 아군 사이 연결선과 실제 견인 속도를 만든다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"lantern")
	own.clear()
	for piece in game.get_pieces():
		if piece.owner_id == 1:
			own.append(piece)
	var lantern := find_effect(game, 1, &"lantern")
	lantern.on_piece_target(game, 1, own[0])
	lantern.on_piece_target(game, 1, own[1])
	await physics_frame
	check(own[1].linear_velocity.length() > 0.0, "lantern physically pulls an allied stone")

	# 07 사목: 서로 다른 네 돌의 격자 연속 배치를 승리로 판정한다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"connect_four")
	own.clear()
	for piece in game.get_pieces():
		if piece.owner_id == 1:
			own.append(piece)
	for index in 4:
		own[index].position = game.board.grid_point(6 + index, 9)
	check(find_effect(game, 1, &"connect_four").check_special_victory(game, 1), "connect four detects four consecutive grid points")

	# 08 눈덩이: 적에게 2턴 상태, 질량, 감속, 시각 상태를 적용하고 복원한다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"snowball")
	var white := first_piece(game, 2)
	find_effect(game, 1, &"snowball").on_piece_target(game, 1, white)
	check(white.status_kind == "snow" and white.mass > 1.0 and white.linear_damp > GameplayRules.BALANCE.linear_damp, "snowball adds weight and drag")
	white.set_stasis(2)
	check("snow" in white.status_kind and "stasis" in white.status_kind, "snowball and stasis coexist")
	white.tick_status(2)
	white.tick_status(2)
	check(white.status_kind == "" and is_equal_approx(white.mass, 1.0) and not white.freeze, "snowball and stasis expire independently")

	# 09 마법사: 변신 후 적에게 화염구 넉백을 전달한다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"wizard")
	black = first_piece(game, 1)
	white = first_piece(game, 2)
	var wizard := find_effect(game, 1, &"wizard")
	wizard.on_piece_target(game, 1, black)
	wizard.on_piece_target(game, 1, white)
	await physics_frame
	await physics_frame
	check(black.transformation == "WIZARD" and white.linear_velocity.length() > 0.0, "wizard transforms and fireball knocks back (velocity=%s)" % white.linear_velocity)

	# 10 탱크 / 14 음속 / 19 조준경은 전용 회귀 테스트와 함께 재확인한다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"tank")
	game.augment_manager.acquire(game, 1, &"sonic_boom")
	game.augment_manager.acquire(game, 1, &"scope")
	black = first_piece(game, 1)
	game.augment_manager.apply_owned_to_piece(1, black)
	var profile: Dictionary = game.augment_manager.shot_profile(1)
	check(is_equal_approx(black.mass, 1.8) and is_equal_approx(float(profile.impulse_multiplier), 1.6) and is_equal_approx(float(profile.max_drag_multiplier), 1.3), "tank, sonic and scope combine (mass=%s profile=%s)" % [black.mass, profile])

	# 11 쿠데타: 실제 소유권과 돌 외형 기반 반지름을 맞바꾼다.
	await reset_game(game)
	black = first_piece(game, 1)
	black.transform_as("HORSE")
	game.swap_all_owners()
	check(black.owner_id == 2 and is_equal_approx(black.base_radius, AlkkagiPiece.WHITE_RADIUS) and black.transformation == "HORSE", "coup swaps ownership while preserving transformation")

	# 12 왕: 상대 끝 도달 후 귀환하면 왕 물리 효과를 얻는다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"king")
	black = first_piece(game, 1)
	black.position.y = AlkkagiBoard.BOARD_RECT.end.y - 10
	find_effect(game, 1, &"king").on_physics_tick(game, 1, 0.016)
	black.position.y = AlkkagiBoard.BOARD_RECT.position.y + 30
	find_effect(game, 1, &"king").on_physics_tick(game, 1, 0.016)
	check(black.transformation == "KING" and black.mass > 1.0, "king journey transforms the returning stone")

	# 13 대검: 범위 내 적에게만 넉백을 준다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"greatsword")
	black = first_piece(game, 1)
	white = first_piece(game, 2)
	black.position = AlkkagiBoard.BOARD_RECT.get_center()
	white.position = black.position + Vector2(60, 0)
	var parked_index := 0
	for parked_piece in game.get_pieces():
		if parked_piece != black and parked_piece != white:
			parked_piece.position = AlkkagiBoard.BOARD_RECT.position + Vector2(45 + parked_index * 48, 42)
			parked_index += 1
	find_effect(game, 1, &"greatsword").on_piece_target(game, 1, black)
	await physics_frame
	await physics_frame
	check(white.linear_velocity.length() > 0.0, "greatsword knocks back an enemy in range (velocity=%s)" % white.linear_velocity)

	# 15 기차: 결정론적 경로 위 돌에 넉백과 예고선을 만든다.
	await reset_game(game)
	game.augment_manager.rng.seed = 321
	var mirror := RandomNumberGenerator.new()
	mirror.seed = 321
	var horizontal := mirror.randi() % 2 == 0
	var ratio := mirror.randf_range(0.25, 0.75)
	black = first_piece(game, 1)
	black.position = Vector2(AlkkagiBoard.BOARD_RECT.get_center().x, AlkkagiBoard.BOARD_RECT.position.y + AlkkagiBoard.BOARD_RECT.size.y * ratio) if horizontal else Vector2(AlkkagiBoard.BOARD_RECT.position.x + AlkkagiBoard.BOARD_RECT.size.x * ratio, AlkkagiBoard.BOARD_RECT.get_center().y)
	game.run_train_event(760.0)
	await physics_frame
	check(black.linear_velocity.length() > 0.0 and not game.board.effect_lines.is_empty(), "train path knocks stones and displays its route")

	# 16 눈보라: 전역 감속을 적용하고 정확히 복원한다.
	await reset_game(game)
	black = first_piece(game, 1)
	game.start_blizzard(2, 2.0, 0.75)
	check(game.board.blizzard_active and black.field_speed_multiplier == 0.75 and black.linear_damp > GameplayRules.BALANCE.linear_damp, "blizzard changes field physics")
	game.tick_field_effects()
	game.tick_field_effects()
	check(not game.board.blizzard_active and black.field_speed_multiplier == 1.0, "blizzard expiration restores field physics")

	# 17 실명: 상대에게만 턴 단위 시야 상태를 부여한다.
	await reset_game(game)
	game.apply_blind(2, 1)
	check(game.blind_turns[2] == 1 and game.blind_turns[1] == 0, "blindness is isolated to the opponent")

	# 18 월마리아: 빈 위치에 실제 StaticBody2D 충돌 벽을 설치한다.
	await reset_game(game)
	var wall_position := AlkkagiBoard.BOARD_RECT.get_center()
	check(not game.position_overlaps_piece(wall_position, 85.0), "wall test position is empty")
	game.spawn_wall(wall_position, 3)
	check(game.temporary_walls.size() == 1 and game.temporary_walls[0].get_child_count() > 0, "wall maria creates a physical collision body")
	game.run_train_event(760.0)
	check(is_instance_valid(game.temporary_walls[0]), "wall remains active during train event")

	# 20 명사수: 제한 각도 안의 적 쪽으로 드래그 방향을 약하게 보정한다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"marksman")
	game.augment_manager.acquire(game, 1, &"scope")
	black = first_piece(game, 1)
	white = first_piece(game, 2)
	white.position = black.position + Vector2(200, 20)
	var raw_pointer := black.position - Vector2(120, 0)
	var corrected := find_effect(game, 1, &"marksman").adjust_pointer(game, 1, black, raw_pointer)
	var raw_angle := absf((black.position - raw_pointer).angle_to(white.position - black.position))
	var corrected_angle := absf((black.position - corrected).angle_to(white.position - black.position))
	check(corrected_angle < raw_angle and corrected_angle > 0.0, "marksman reduces aim error without guaranteeing a hit")
	check(float(game.augment_manager.shot_profile(1).guide_multiplier) > 1.5, "scope and marksman combine their guide multipliers")
	game.start_blizzard(2, 2.0, 0.75)
	var corrected_in_snow := find_effect(game, 1, &"marksman").adjust_pointer(game, 1, black, raw_pointer)
	check(corrected_in_snow.is_equal_approx(corrected), "blizzard does not corrupt marksman aim calculation")

	game.begin_match()
	check(game.augment_manager.owned[1].is_empty() and game.temporary_walls.is_empty(), "restart clears all augment and field state")
	if failures == 0:
		print("PASS: all 20 augment gameplay effects tests")
	quit(failures)
