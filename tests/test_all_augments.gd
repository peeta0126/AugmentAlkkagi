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
	check(game.augment_manager.CATALOG.size() == 25, "catalog registers all 25 augments")
	var ids := {}
	for definition in game.augment_manager.CATALOG:
		ids[definition.id] = true
	check(ids.size() == 25, "all augment IDs are unique")
	game.augment_manager.reset_match()
	for index in 3:
		check(game.augment_manager.acquire(game, 1, game.augment_manager.CATALOG[index].id), "acquire succeeds within cap")
	check(not game.augment_manager.acquire(game, 1, game.augment_manager.CATALOG[3].id), "a player cannot own a fourth augment")
	check(game.augment_manager.owned[1].size() == GameplayRules.MAX_AUGMENTS_PER_PLAYER, "inventory is capped at three augments")
	game.augment_manager.reset_match()

	# 01 삼연발: 원본 하나가 물리 충돌을 가진 소형 돌 셋으로 교체된다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"triple_shot")
	game.augment_manager.acquire(game, 1, &"sonic_boom")
	var original := first_piece(game, 1)
	var before_count: int = game.count_owner(1)
	var triple := find_effect(game, 1, &"triple_shot")
	check(not triple.transform_shot(game, 1, original, Vector2(400, 0)), "triple shot does not trigger before activation")
	triple.activate_immediate(game, 1)
	check(triple.armed and triple.uses_left == 0, "triple shot arms once and consumes its use")
	triple.transform_shot(game, 1, original, Vector2(400, 0))
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
	check(not triple.armed, "triple shot disarms after the next shot")
	for piece in game.get_pieces():
		if piece.owner_id == 1 and piece.fragment_factor < 1.0:
			check(piece.linear_velocity.length() > 200.0, "triple-shot fragments leave at about 70 percent of the shot speed")

	# 02 존야: 실제 스킬 선택 상태, 동결, 무적, 지속 종료를 검증한다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"stasis")
	var stasis := find_effect(game, 1, &"stasis")
	stasis.begin_active(game, 1)
	check(game.state_machine.current == GameStateMachine.State.SKILL_TARGETING, "active skill enters targeting state")
	var black := first_piece(game, 1)
	game._on_piece_pressed(black)
	check(black.freeze and black.invulnerable, "stasis freezes and protects its target")
	check(stasis.uses_left == 0, "stasis has one use")
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
	check(is_equal_approx(black.mass_factor, 1.0) and is_equal_approx(black.status_damp_bonus, 0.0) and is_equal_approx(black.speed_cap, GameplayRules.BALANCE.max_speed), "janggi keeps base mass, drag, and speed")

	# 05 업기: 두 돌을 한 스택으로 합치고 질량/외형을 변경한다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"piggyback")
	var own: Array[AlkkagiPiece] = []
	for piece in game.get_pieces():
		if piece.owner_id == 1:
			own.append(piece)
	var piggy := find_effect(game, 1, &"piggyback")
	check(piggy.on_piece_target(game, 1, own[0]), "merge accepts one allied anchor")
	await process_frame
	check(own[0].carried_count == GameplayRules.DEFAULT_PIECES - 1 and own[0].mass > 4.0, "merge absorbs every allied stone into a much heavier stack")
	check(find_effect(game, 1, &"piggyback").definition.display_name == "합체", "merge keeps the compatible piggyback id with the new name")
	check(game.count_owner(1) == 1, "piggyback leaves exactly one allied stone")

	# 06 랜턴: 두 아군 사이 연결선과 실제 견인 속도를 만든다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"lantern")
	own.clear()
	for piece in game.get_pieces():
		if piece.owner_id == 1:
			own.append(piece)
	var lantern: LanternAugmentEffect = find_effect(game, 1, &"lantern")
	var lantern_position := AlkkagiBoard.BOARD_RECT.get_center()
	check(lantern.on_position_target(game, 1, lantern_position), "lantern installs at a valid board position")
	own[1].position = lantern_position
	own[1].linear_velocity = Vector2.RIGHT * 20.0
	lantern.on_physics_tick(game, 1, 0.016)
	check(lantern.pieces_inside.has(own[1].piece_id), "lantern detects an allied stone entering its field")
	await physics_frame
	check(own[1].linear_velocity.length() > 20.0, "lantern accelerates an allied stone (velocity=%s)" % own[1].linear_velocity)
	check(game.board.field_visuals.has("lantern_1"), "installed lantern remains visible on the board")

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
	var flexible_origin := Vector2(500, 310)
	for index in 4:
		own[index].position = flexible_origin + Vector2(index * 45.0, [-7.0, 5.0, -4.0, 6.0][index])
	check(find_effect(game, 1, &"connect_four").check_special_victory(game, 1), "connect four accepts near-linear stones with wider legal gaps")
	check(game.board.field_visuals.has("connect_four_1"), "connect four exposes its winning line visual")
	own[3].position.x += 80.0
	check(not find_effect(game, 1, &"connect_four").check_special_victory(game, 1), "connect four rejects a sequence with an excessive gap")

	# 08 눈덩이: 적에게 2턴 상태, 질량, 감속, 시각 상태를 적용하고 복원한다.
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"snowball")
	var white := first_piece(game, 2)
	var snowball: SnowballAugmentEffect = find_effect(game, 1, &"snowball")
	var snow_origin: Vector2 = game.player_center(1)
	white.position = snow_origin + Vector2(120, 0)
	check(snowball.on_position_target(game, 1, snow_origin + Vector2(300, 0)), "snowball accepts an aimed board position")
	for step in 20:
		snowball.on_physics_tick(game, 1, 0.02)
		if not snowball.projectile_active:
			break
	check(white.status_kind == "snow" and white.freeze and is_equal_approx(white.mass, 1.0), "snowball freezes only an actually hit enemy without changing mass")
	white.set_stasis(2)
	check("snow" in white.status_kind and "stasis" in white.status_kind, "snowball and stasis coexist")
	white.tick_status(2)
	white.tick_status(2)
	check(white.status_kind == "" and is_equal_approx(white.mass, 1.0) and not white.freeze, "snowball and stasis expire independently")
	await reset_game(game)
	game.augment_manager.acquire(game, 1, &"snowball")
	snowball = find_effect(game, 1, &"snowball")
	snow_origin = game.player_center(1)
	for piece: AlkkagiPiece in game.get_pieces():
		if piece.owner_id == 2:
			piece.position = Vector2(420 + piece.piece_id % 5 * 40, 580)
	snowball.on_position_target(game, 1, snow_origin + Vector2(300, 0))
	for step in 80:
		snowball.on_physics_tick(game, 1, 0.02)
		if not snowball.projectile_active:
			break
	check(not snowball.projectile_active and not game.get_pieces().any(func(piece: AlkkagiPiece): return piece.owner_id == 2 and piece.status_kind == "snow"), "missed snowball expires without freezing an enemy")

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
	var tank := find_effect(game, 1, &"tank")
	tank.on_piece_target(game, 1, black)
	await process_frame
	check(is_instance_valid(black.tank_visual) and black.tank_visual.sprite.texture.resource_path.ends_with("tank_black.png"), "black stone uses black tank sprite")
	var original_tank_width := black.tank_visual.sprite.scale.x
	black.tank_visual.size_multiplier = 1.5
	check(is_equal_approx(black.tank_visual.sprite.scale.x, original_tank_width * 1.5), "Inspector size multiplier resizes tank image")
	black.tank_visual.size_multiplier = 1.0
	black.linear_velocity = Vector2(150, 0)
	black.tank_visual._physics_process(1.0)
	check(is_equal_approx(black.tank_visual.rotation, PI * 0.5), "tank barrel faces right when stone flies right")
	black.linear_velocity = Vector2.ZERO
	black.tank_visual._physics_process(1.0)
	check(is_equal_approx(black.tank_visual.rotation, PI * 0.5), "stopped tank keeps its last facing direction")
	black.linear_velocity = Vector2(0, -150)
	black.tank_visual._physics_process(1.0)
	check(is_zero_approx(black.tank_visual.rotation), "tank barrel faces up when stone flies up")
	black.linear_velocity = Vector2.ZERO
	black.change_player_owner(2)
	check(black.tank_visual.sprite.texture.resource_path.ends_with("tank_white.png"), "owner change updates tank to white sprite")
	check(black.tank_visual.scene_file_path.ends_with("tank_white.tscn"), "white tank has its own scene in Effects")
	var visible_white_width := black.tank_visual.sprite.scale.x * 1077.0
	var visible_white_height := black.tank_visual.sprite.scale.y * 1151.0
	check(is_equal_approx(visible_white_width, 56.0 * 982.0 / 1312.0), "white visible width matches black visible artwork")
	check(is_equal_approx(visible_white_height, 56.0 * 1071.0 / 1199.0), "white visible height matches black visible artwork")
	black.change_player_owner(1)
	check(black.tank_visual.sprite.texture.resource_path.ends_with("tank_black.png"), "owner restoration updates tank to black sprite")
	check(black.tank_visual.scene_file_path.ends_with("tank.tscn"), "black tank returns to its scene")
	var profile: Dictionary = game.augment_manager.shot_profile(1)
	check(is_equal_approx(black.mass, 1.8) and is_equal_approx(float(profile.impulse_multiplier), 1.6) and is_equal_approx(float(profile.max_drag_multiplier), 1.3), "tank, sonic and scope combine (mass=%s profile=%s)" % [black.mass, profile])
	check(not tank.on_piece_target(game, 1, black), "tank cannot be applied twice to the same stone")

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
	check(black.transformation == "KING" and black.mass >= 2.0 and black.visual_radius >= black.base_radius * 1.49, "king journey creates a visibly larger, doubled-mass king")
	white = first_piece(game, 2)
	white.position = black.position + Vector2(35, 0)
	find_effect(game, 1, &"king").on_piece_collision(game, 1, black, white)
	check(not black.king_shockwave_available, "king consumes one synchronized shockwave on its first enemy collision")
	var velocity_after_first := white.linear_velocity
	find_effect(game, 1, &"king").on_piece_collision(game, 1, black, white)
	check(white.linear_velocity.is_equal_approx(velocity_after_first), "king shockwave cannot trigger twice")

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
	game.augment_manager.acquire(game, 1, &"train")
	var train: TrainAugmentEffect = find_effect(game, 1, &"train")
	check(not game.augment_manager.active_effects(1).has(train), "train is passive and is absent from active skill buttons")
	train.on_global_turn_ended(game, 1)
	check(train.phase == TrainAugmentEffect.Phase.WARNING and game.board.field_visuals.has("train_warning_1"), "train shows its route before passing")
	check(train.blocks_turn_resolution(), "turn does not resolve while the train route is being previewed")
	var warned_path := train.warned_path.duplicate()
	check(not warned_path.is_empty(), "train warning retains a concrete host-selected route until passage")
	train.on_physics_tick(game, 1, TrainAugmentEffect.WARNING_SECONDS - 0.1)
	check(train.phase == TrainAugmentEffect.Phase.WARNING, "train keeps warning until 1.5 seconds have passed")
	train.on_physics_tick(game, 1, 0.2)
	check(train.phase == TrainAugmentEffect.Phase.IDLE and train.warned_path.is_empty() and not game.board.field_visuals.has("train_warning_1"), "train passes after the warning and clears its preview")

	# 16 눈보라: 획득 즉시 적용하고 게임이 끝날 때까지 유지한다.
	await reset_game(game)
	black = first_piece(game, 1)
	var original_damp := black.linear_damp
	check(game.augment_manager.acquire(game, 1, &"blizzard"), "blizzard acquisition succeeds")
	check(game.board.blizzard_active and black.field_speed_multiplier == 1.15 and black.linear_damp < original_damp, "blizzard activates immediately on acquisition")
	check(game.augment_manager.active_effects(1).is_empty(), "blizzard has no manual activation button")
	for turn in 100:
		game.tick_field_effects()
	check(game.blizzard_turns == -1 and game.board.blizzard_active and black.field_damp_multiplier == 0.28, "blizzard never expires on turn completion")
	game.spawn_piece(1, 999, Vector2(600, 400))
	check(game.find_piece(999).field_damp_multiplier == 0.28, "new stones inherit permanent blizzard")
	var blizzard_snapshot: Dictionary = game.create_network_snapshot()
	game.reset_runtime_effects()
	game.apply_network_snapshot(blizzard_snapshot)
	check(game.blizzard_turns == -1 and game.board.blizzard_active and black.field_speed_multiplier == 1.15 and black.field_damp_multiplier == 0.28, "snapshot restores permanent blizzard visuals and physics")
	await reset_game(game)
	check(game.blizzard_turns == 0 and not game.board.blizzard_active and first_piece(game, 1).field_damp_multiplier == 1.0, "new match clears permanent blizzard")
	game.clear_world()
	game.augment_manager.reset_match()
	game.reset_runtime_effects()
	game.board = null
	check(game.augment_manager.acquire(game, 1, &"blizzard"), "initial selection can acquire blizzard before board creation")
	game.start_game_world()
	check(game.board.blizzard_active and first_piece(game, 1).field_damp_multiplier == 0.28, "initial board starts with permanent blizzard")

	# 17 실명: 상대에게만 턴 단위 시야 상태를 부여한다.
	await reset_game(game)
	game.apply_blind(2, 1)
	check(game.blind_turns[2] == 1 and game.blind_turns[1] == 0, "blindness is isolated to the opponent")
	game.online_mode = true
	game.local_player_id = 2
	game.current_player = 2
	game.build_hud()
	check(game.blind_material != null, "blindness uses a local sight-limited material")
	black = first_piece(game, 2)
	game.board.set_aim(black.position, black.position + Vector2(90, 0), Color.WHITE)
	game._update_blind_centers()
	check(game.blind_visual != null and game.blind_visual.aim_guide.visible, "blindness preserves the essential local aiming guide above the veil")
	game.online_mode = false

	# 18 월마리아: 빈 위치에 실제 StaticBody2D 충돌 벽을 설치한다.
	await reset_game(game)
	var wall_position := AlkkagiBoard.BOARD_RECT.get_center()
	check(game.can_place_wall(wall_position, PI * 0.5), "wall test position is empty")
	game.augment_manager.acquire(game, 1, &"wall_maria")
	var wall_effect: WallMariaAugmentEffect = find_effect(game, 1, &"wall_maria")
	wall_effect.update_target_preview(game, 1, wall_position)
	check(wall_effect.preview != null and wall_effect.preview.modulate.is_equal_approx(wall_effect.preview.preview_valid_color), "wall maria shows a valid placement silhouette")
	wall_effect.on_targeting_key(game, 1, KEY_R)
	check(wall_effect.vertical and is_equal_approx(wall_effect.preview.rotation, PI * 0.5), "R toggles the wall preview between horizontal and vertical")
	wall_effect.cancel_active()
	check(game.spawn_wall(wall_position, 3, PI * 0.5), "valid wall placement succeeds")
	var wall: TemporaryWall = game.temporary_walls[0]
	var wall_collision := wall.get_node("WallCollision") as CollisionShape2D
	check(wall is StaticBody2D and wall_collision != null and wall_collision.shape is RectangleShape2D, "wall maria creates a StaticBody2D rectangle collider")
	check(wall.collision_layer == GameplayRules.WALL_COLLISION_LAYER, "wall uses the configured collision layer")
	black = first_piece(game, 1)
	check(not game.can_place_wall(black.position, 0.0), "wall placement rejects overlap with a stone")
	check(not game.can_place_wall(wall_position, 0.0), "wall placement rejects overlap with an existing wall")
	black.position = wall_position - Vector2(110, 0)
	black.prepare_shot_speed_cap(GameplayRules.BALANCE.max_speed * 1.6)
	black.sleeping = false
	black.linear_velocity = Vector2(GameplayRules.BALANCE.max_speed * 1.6, 0)
	for frame in 15:
		await physics_frame
	check(black.position.x < wall_position.x + GameplayRules.WALL_SIZE.y * 0.5 + black.visual_radius, "high-speed stone does not tunnel through the wall")
	var snapshot: Dictionary = game.create_network_snapshot()
	var wall_states: PackedFloat32Array = snapshot.walls
	check(wall_states.size() == 5 and is_equal_approx(wall_states[3], PI * 0.5), "network snapshot preserves wall rotation")
	game.tick_field_effects()
	game.tick_field_effects()
	game.tick_field_effects()
	check(game.temporary_walls.is_empty(), "wall collider is removed when duration expires")

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
	game.start_blizzard(2, 0.28, 1.15)
	var corrected_in_snow := find_effect(game, 1, &"marksman").adjust_pointer(game, 1, black, raw_pointer)
	check(corrected_in_snow.is_equal_approx(corrected), "blizzard does not corrupt marksman aim calculation")

	game.begin_match()
	check(game.augment_manager.owned[1].is_empty() and game.temporary_walls.is_empty(), "restart clears all augment and field state")
	if failures == 0:
		print("PASS: existing augment gameplay effects tests with version 2 changes")
	quit(failures)
