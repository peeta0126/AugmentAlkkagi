extends SceneTree

const NETWORK_MODE_OFFLINE := 0
const NETWORK_MODE_HOST := 1
var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func close_enough(actual: float, expected: float, message: String) -> void:
	check(absf(actual - expected) < 0.001, "%s (actual %.3f, expected %.3f)" % [message, actual, expected])

func run_test() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame

	game.begin_match()
	await process_frame
	check(game.state_machine.current == GameStateMachine.State.PIECE_PLACEMENT, "match starts in piece placement")
	check(game.validate_player_placement(1) and game.validate_player_placement(2), "default placement is valid for both players")
	game._confirm_placement()
	game._confirm_placement()
	await process_frame
	check(game.state_machine.current == GameStateMachine.State.INITIAL_AUGMENT_SELECTION, "both placements advance to initial augment selection")
	check(game.current_choices.size() == 3, "initial selection offers three cards")
	var unique_ids := {}
	for definition in game.current_choices:
		unique_ids[definition.id] = true
	check(unique_ids.size() == 3, "selection contains no duplicate cards")
	check(not game.state_machine.allows_aiming(), "selection blocks aiming")

	var red_choice: StringName = game.current_choices[0].id
	game._choose_augment(red_choice)
	await process_frame
	check(game.augment_manager.has_augment(1, red_choice), "black independently owns its choice")
	check(not game.augment_manager.has_augment(2, red_choice), "choice is not given to white")
	check(game.selection_player == 2, "selection advances to blue")
	game._choose_augment(game.current_choices[0].id)
	await process_frame
	check(game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, "both initial choices start gameplay")

	# 핵심 세 증강의 물리 검증은 무작위 선택과 분리한다.
	game.clear_world()
	game.augment_manager.reset_match()
	game.augment_manager.acquire(game, 1, &"tank")
	game.augment_manager.acquire(game, 2, &"sonic_boom")
	game.start_game_world()
	await process_frame

	var red_piece: AlkkagiPiece
	var blue_piece: AlkkagiPiece
	for piece in game.get_pieces():
		if piece.owner_id == 1 and red_piece == null:
			red_piece = piece
		elif piece.owner_id == 2 and blue_piece == null:
			blue_piece = piece
	red_piece.apply_tank(1.25, 1.8)
	close_enough(red_piece.visual_radius, AlkkagiPiece.BLACK_RADIUS * 1.25, "tank visual size")
	close_enough(red_piece.mass, 1.8, "tank mass")
	close_enough((red_piece.collision_shape.shape as CircleShape2D).radius, red_piece.visual_radius, "tank collider matches visual")
	close_enough(blue_piece.visual_radius, AlkkagiPiece.WHITE_RADIUS, "tank does not affect opponent")
	check(red_piece.gravity_scale == 0.0 and blue_piece.gravity_scale == 0.0, "piece gravity is explicitly disabled")
	var red_start := red_piece.position
	await physics_frame
	await physics_frame
	check(red_piece.position.distance_to(red_start) < 0.01, "pieces do not fall or move after spawning")

	var blue_profile: Dictionary = game.augment_manager.shot_profile(2)
	close_enough(float(blue_profile.impulse_multiplier), 1.6, "sonic boom increases shot impulse")
	game.current_player = 2
	game._on_piece_pressed(blue_piece)
	game.fire_selected(blue_piece.global_position + Vector2(100, 0))
	await physics_frame
	check(blue_piece.sonic_trail, "sonic shot enables enhanced trail")
	check(blue_piece.continuous_cd == RigidBody2D.CCD_MODE_CAST_RAY, "sonic piece uses CCD")

	# 네 번째 완료 턴에서 추가 선택을 끼워 넣고 다음 플레이어로 복귀한다.
	game.state_machine.transition(GameStateMachine.State.PIECES_MOVING)
	game.current_player = 1
	game.resolve_turn()
	await process_frame
	check(game.round_count == 0 and bool(game.round_actions[1]), "black action alone does not complete a round")
	game.round_count = 2
	game.state_machine.transition(GameStateMachine.State.PIECES_MOVING)
	game.current_player = 2
	game.resolve_turn()
	await process_frame
	check(game.round_count == 3, "white action completes the shared third round")
	check(game.state_machine.current == GameStateMachine.State.AUGMENT_SELECTION, "third shared round opens augment selection")
	check(game.current_choices.size() == 3, "additional selection still offers three unowned augments")
	game._choose_augment(game.current_choices[0].id)
	await process_frame
	check(game.state_machine.current == GameStateMachine.State.AUGMENT_SELECTION and game.selection_player == 2, "local reward waits for white selection")
	game._choose_augment(game.current_choices[0].id)
	await process_frame
	check(game.current_player == 1 and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, "both reward choices resume the next round")
	check(game.augment_manager.owned[1].size() == 2 and game.augment_manager.owned[2].size() == 2, "third-round reward grants one augment to each player")
	game.round_count = 5
	game.round_actions = {1: true, 2: false}
	game.current_player = 2
	game.state_machine.transition(GameStateMachine.State.PIECES_MOVING)
	game.resolve_turn()
	await process_frame
	check(game.round_count == 6 and game.state_machine.current == GameStateMachine.State.AUGMENT_SELECTION, "sixth shared round opens the final selection")
	game._choose_augment(game.current_choices[0].id)
	await process_frame
	game._choose_augment(game.current_choices[0].id)
	await process_frame
	check(game.augment_manager.owned[1].size() == 3 and game.augment_manager.owned[2].size() == 3, "sixth-round reward fills both inventories")
	game.round_count = 8
	game.round_actions = {1: true, 2: false}
	game.current_player = 2
	game.state_machine.transition(GameStateMachine.State.PIECES_MOVING)
	game.resolve_turn()
	await process_frame
	check(game.round_count == 9 and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, "ninth round adds no selection after inventories are full")
	check(game.augment_manager.owned[1].size() == 3 and game.augment_manager.owned[2].size() == 3, "ninth round cannot add a fourth augment")

	game.augment_manager.reset_match()
	for augment_id in [&"tank", &"sonic_boom", &"scope"]:
		check(game.augment_manager.acquire(game, 1, augment_id), "first three augments are accepted")
	check(not game.augment_manager.acquire(game, 1, &"marksman"), "fourth augment is rejected")
	check(game.augment_manager.get_choices(1, 3).is_empty(), "full inventory produces no card offer")

	# 효과 획득 순서가 달라도 수치 곱 결과는 동일하다.
	game.augment_manager.reset_match()
	game.augment_manager.acquire(game, 1, &"sonic_boom")
	game.augment_manager.acquire(game, 1, &"scope")
	game.augment_manager.acquire(game, 2, &"scope")
	game.augment_manager.acquire(game, 2, &"sonic_boom")
	var order_a: Dictionary = game.augment_manager.shot_profile(1)
	var order_b: Dictionary = game.augment_manager.shot_profile(2)
	close_enough(float(order_a.impulse_multiplier), float(order_b.impulse_multiplier), "stacking impulse is order independent")
	close_enough(float(order_a.max_drag_multiplier), float(order_b.max_drag_multiplier), "stacking range is order independent")
	var base_max := GameplayRules.BALANCE.max_launch_impulse
	var stacked_max := base_max * float(order_a.max_drag_multiplier) * float(order_a.impulse_multiplier)
	close_enough(stacked_max, base_max * 2.08, "sonic and scope combine to 2.08x maximum impulse")
	close_enough(float(order_a.guide_multiplier), 1.5, "scope lengthens aiming guide")

	# 탱크의 본체 변경과 음속의 발사 프로필은 서로 독립적으로 함께 적용된다.
	game.augment_manager.reset_match()
	game.augment_manager.acquire(game, 1, &"tank")
	game.augment_manager.acquire(game, 1, &"sonic_boom")
	var combo_piece := AlkkagiPiece.new()
	combo_piece.setup(1, 999)
	root.add_child(combo_piece)
	combo_piece.apply_tank(1.25, 1.8)
	close_enough(combo_piece.mass, 1.8, "tank and sonic preserve tank mass")
	close_enough(float(game.augment_manager.shot_profile(1).impulse_multiplier), 1.6, "tank and sonic preserve sonic impulse")
	combo_piece.queue_free()
	await process_frame

	# CCD가 켜진 고속 알이 한 물리 프레임 사이를 건너뛰지 않고 목표에 충격을 준다.
	var projectile := AlkkagiPiece.new()
	projectile.setup(1, 1001)
	projectile.position = Vector2(120, 690)
	var sonic_speed := GameplayRules.BALANCE.max_speed * 1.6
	projectile.activate_sonic_trail(sonic_speed)
	root.add_child(projectile)
	var target := AlkkagiPiece.new()
	target.setup(2, 1002)
	target.position = Vector2(300, 690)
	root.add_child(target)
	projectile.linear_velocity = Vector2(sonic_speed, 0)
	for frame in 12:
		await physics_frame
	check(target.linear_velocity.x > 0.0, "high-speed CCD collision transfers momentum")
	projectile.queue_free()
	target.queue_free()
	await process_frame

	game.begin_match()
	check(game.augment_manager.owned[1].is_empty() and game.augment_manager.completed_turns[1] == 0 and game.round_count == 0, "local restart clears augments and counters")
	game.augment_manager.acquire(game, 1, &"tank")
	game.round_count = 5
	game.round_actions = {1: true, 2: false}
	game.network_prepare_match(false, 2, 3)
	check(game.augment_manager.owned[1].is_empty() and game.round_count == 0 and not bool(game.round_actions[1]), "network rematch preparation clears augments and round progress")
	var validated_targets: Array[int] = []
	check(game.network_manager.validate_active_target_ids([], validated_targets) and validated_targets.is_empty(), "RPC validation accepts an untyped empty target array")
	check(game.network_manager.validate_active_target_ids([101, 102], validated_targets) and validated_targets == [101, 102], "RPC validation converts integer target IDs to Array[int]")
	check(not game.network_manager.validate_active_target_ids(["invalid"], validated_targets), "RPC validation rejects non-integer target IDs")

	# All active targeting modes keep Array[int] at the submit/host-processing boundary.
	game.online_mode = false
	game.network_manager.mode = NETWORK_MODE_HOST
	game.network_manager.match_active = true
	game.start_game()
	game.augment_manager.acquire(game, 1, &"wall_maria")
	var no_targets: Array[int] = []
	game.network_manager.submit_active_skill(&"wall_maria", no_targets, AlkkagiBoard.BOARD_RECT.get_center())
	check(game.temporary_walls.size() == 1, "board-position active accepts typed empty targets")
	check(is_zero_approx(game.temporary_walls[0].rotation), "wall maria defaults to horizontal placement")

	game.start_game()
	game.augment_manager.acquire(game, 1, &"wall_maria")
	game.network_manager.submit_active_skill(&"wall_maria", no_targets, AlkkagiBoard.BOARD_RECT.get_center(), 1)
	check(game.temporary_walls.size() == 1 and is_equal_approx(game.temporary_walls[0].rotation, PI * 0.5), "host validates and applies the client's vertical wall option")

	game.start_game()
	game.augment_manager.acquire(game, 1, &"coup")
	game.network_manager.submit_active_skill(&"coup", no_targets)
	check(game.state_machine.current == GameStateMachine.State.PIECES_MOVING, "targetless active accepts typed empty targets")

	game.start_game()
	game.augment_manager.acquire(game, 1, &"snowball")
	var white_target: AlkkagiPiece
	for piece in game.get_pieces():
		if piece.owner_id == 2:
			white_target = piece
			break
	var snow_origin: Vector2 = game.player_center(1)
	white_target.position = snow_origin + Vector2(100, 0)
	game.network_manager.submit_active_skill(&"snowball", no_targets, snow_origin + Vector2(260, 0))
	var snow_effect: SnowballAugmentEffect
	for effect: AugmentEffect in game.augment_manager.effects[1]:
		if effect.definition.id == &"snowball":
			snow_effect = effect as SnowballAugmentEffect
	for step in 20:
		snow_effect.on_physics_tick(game, 1, 0.02)
		if not snow_effect.projectile_active:
			break
	check(white_target.status_kind == "snow", "board-position snowball request freezes on host-confirmed collision")

	game.start_game()
	game.augment_manager.acquire(game, 1, &"piggyback")
	var own_targets: Array[int] = []
	for piece in game.get_pieces():
		if piece.owner_id == 1 and own_targets.is_empty():
			own_targets.append(piece.piece_id)
	var before_merge: int = game.count_owner(1)
	game.network_manager.submit_active_skill(&"piggyback", own_targets)
	await process_frame
	check(game.count_owner(1) == 1 and before_merge > 1, "merge request absorbs every allied stone from one anchor id")
	game.network_manager.mode = NETWORK_MODE_OFFLINE
	if failures == 0:
		print("PASS: augment system and effects tests")
	quit(failures)
