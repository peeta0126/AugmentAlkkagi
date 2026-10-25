extends SceneTree

const LEGACY_MAX_IMPULSE := 624.0
const LEGACY_LINEAR_DAMP := 3.35
var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func close_enough(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s (actual=%.3f expected=%.3f)" % [message, actual, expected])

func run_test() -> void:
	var balance := GameplayRules.BALANCE
	check(is_equal_approx(balance.max_launch_impulse, LEGACY_MAX_IMPULSE * 1.8), "maximum launch impulse is exactly 1.8x legacy")
	check(is_equal_approx(balance.linear_damp, LEGACY_LINEAR_DAMP * 0.8), "linear damp is 80 percent of legacy")

	var origin := Vector2(500, 500)
	var quarter := GameplayRules.shot_impulse(origin, origin - Vector2(balance.drag_distance * 0.25, 0))
	var half := GameplayRules.shot_impulse(origin, origin - Vector2(balance.drag_distance * 0.5, 0))
	var maximum := GameplayRules.shot_impulse(origin, origin - Vector2(balance.drag_distance, 0))
	close_enough(quarter.length(), balance.max_launch_impulse * 0.25, 0.01, "quarter drag gives quarter power")
	close_enough(half.length(), balance.max_launch_impulse * 0.5, 0.01, "half drag gives half power")
	close_enough(maximum.length(), balance.max_launch_impulse, 0.01, "full drag reaches maximum power")
	check(quarter.length() < half.length() and half.length() < maximum.length(), "drag power is monotonic")
	for test_mass: float in [1.0, 1.8, 2.0, 4.6]:
		close_enough(GameplayRules.mass_compensated_launch_impulse(half, test_mass).length() / test_mass, half.length(), 0.01, "half-charge target speed is mass independent at mass %.1f" % test_mass)
		close_enough(GameplayRules.mass_compensated_launch_impulse(maximum, test_mass).length() / test_mass, maximum.length(), 0.01, "full-charge target speed is mass independent at mass %.1f" % test_mass)

	var small_result: Dictionary = await measure_shot(quarter)
	var max_result: Dictionary = await measure_shot(maximum)
	check(float(small_result.distance) > 40.0, "small shot produces visible movement")
	check(float(max_result.distance) > float(small_result.distance) * 2.8, "maximum shot travels substantially farther")
	check(float(max_result.stop_time) < 4.0, "maximum shot still settles in finite time")

	# 발사 전용 질량 보정은 강화 돌의 초기 속도와 자유 이동 거리만 정규화한다.
	var variant_results: Dictionary = {}
	for variant in ["normal", "tank", "king", "merge"]:
		variant_results[variant] = await measure_variant_shot(variant, maximum)
	var normal_speed := float(variant_results.normal.initial_speed)
	var normal_distance := float(variant_results.normal.distance)
	for variant in ["tank", "king", "merge"]:
		close_enough(float(variant_results[variant].initial_speed), normal_speed, 0.5, "%s launch speed matches normal stone" % variant)
		close_enough(float(variant_results[variant].distance), normal_distance, maxf(normal_distance * 0.03, 3.0), "%s unobstructed distance matches normal stone" % variant)
		check(float(variant_results[variant].mass) > 1.0, "%s keeps its increased collision mass" % variant)
	var normal_collision: Dictionary = await measure_variant_collision("normal", maximum)
	var tank_collision: Dictionary = await measure_variant_collision("tank", maximum)
	check(float(tank_collision.target_speed) > float(normal_collision.target_speed) * 1.08, "tank keeps stronger momentum transfer at equal launch speed")

	var legacy_estimated_distance := estimate_slide_distance(LEGACY_MAX_IMPULSE, LEGACY_LINEAR_DAMP)
	var improved_estimated_distance := estimate_slide_distance(balance.max_launch_impulse, balance.linear_damp)
	check(improved_estimated_distance > legacy_estimated_distance * 2.0, "new tuning more than doubles estimated travel distance")

	var collision_result: Dictionary = await measure_collision(maximum)
	check(float(collision_result.target_speed) > 100.0, "maximum shot transfers meaningful speed to another stone")

	# 실제 매치 경로에서 강한 발사, 경계 제거, 정지 후 턴 교대가 함께 끝나는지 확인한다.
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.start_game()
	await process_frame
	var leftmost: AlkkagiPiece
	for piece in game.get_pieces():
		if piece.owner_id == 1 and (leftmost == null or piece.position.x < leftmost.position.x):
			leftmost = piece
	var black_before: int = game.count_owner(1)
	game._on_piece_pressed(leftmost)
	game.fire_selected(leftmost.position + Vector2(balance.drag_distance, 0))
	var turn_frames := 0
	while turn_frames < 300 and not (game.current_player == 2 and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING):
		await physics_frame
		turn_frames += 1
	check(game.current_player == 2 and game.state_machine.current == GameStateMachine.State.PLAYER_AIMING, "strong shot settles and advances the turn")
	check(game.count_owner(1) < black_before, "maximum outward shot is removed beyond the board")
	game.queue_free()
	await process_frame

	# 증강의 최종 충격량과 안전 속도 상한은 같은 곱셈 프로필을 사용한다.
	var manager := AugmentManager.new()
	root.add_child(manager)
	await process_frame
	manager.acquire(manager, 1, &"sonic_boom")
	manager.acquire(manager, 1, &"scope")
	var profile := manager.shot_profile(1)
	close_enough(float(profile.impulse_multiplier), 1.6, 0.001, "sonic multiplier remains 1.6")
	close_enough(float(profile.max_drag_multiplier), 1.3, 0.001, "scope range multiplier remains 1.3")
	close_enough(float(profile.speed_multiplier), 2.08, 0.001, "combined speed cap follows final 2.08 multiplier")
	var enhanced_max := GameplayRules.shot_impulse(origin, origin - Vector2(balance.drag_distance * 1.3, 0), balance.drag_distance * 1.3, 1.6)
	close_enough(enhanced_max.length(), balance.max_launch_impulse * 2.08, 0.1, "scope and sonic maximum impulse is 2.08x base")
	close_enough(GameplayRules.mass_compensated_launch_impulse(enhanced_max, 4.6).length() / 4.6, enhanced_max.length(), 0.1, "scope and sonic target speed remains mass independent")

	print("MASS_LAUNCH_COMPARE normal=(m=%.2f v=%.2f d=%.2f) tank=(m=%.2f v=%.2f d=%.2f) king=(m=%.2f v=%.2f d=%.2f) merge=(m=%.2f v=%.2f d=%.2f) collision_normal=%.2f collision_tank=%.2f" % [variant_results.normal.mass, variant_results.normal.initial_speed, variant_results.normal.distance, variant_results.tank.mass, variant_results.tank.initial_speed, variant_results.tank.distance, variant_results.king.mass, variant_results.king.initial_speed, variant_results.king.distance, variant_results.merge.mass, variant_results.merge.initial_speed, variant_results.merge.distance, normal_collision.target_speed, tank_collision.target_speed])
	print("BALANCE_MEASURE legacy_estimated_distance=%.2f improved_estimated_distance=%.2f small_actual_distance=%.2f max_actual_distance=%.2f max_stop_time=%.2f collision_target_speed=%.2f" % [legacy_estimated_distance, improved_estimated_distance, small_result.distance, max_result.distance, max_result.stop_time, collision_result.target_speed])
	if failures == 0:
		print("PASS: launch power and physics balance tests")
	quit(failures)

func measure_shot(impulse: Vector2) -> Dictionary:
	var piece := AlkkagiPiece.new()
	piece.setup(1, randi())
	piece.position = Vector2(100, 680)
	root.add_child(piece)
	await physics_frame
	var start := piece.position
	piece.sleeping = false
	piece.apply_central_impulse(impulse)
	var frames := 0
	while frames < 360:
		await physics_frame
		frames += 1
		if piece.linear_velocity.is_zero_approx() and frames > 2:
			break
	var result := {"distance": piece.position.distance_to(start), "stop_time": frames / 60.0}
	piece.queue_free()
	await process_frame
	return result

func measure_variant_shot(variant: String, reference_impulse: Vector2) -> Dictionary:
	var piece := AlkkagiPiece.new()
	piece.setup(1, randi())
	piece.position = Vector2(100, 680)
	root.add_child(piece)
	await physics_frame
	_configure_variant(piece, variant)
	await physics_frame
	var start := piece.position
	piece.sleeping = false
	piece.apply_launch_impulse(reference_impulse)
	var measured_mass := piece.mass
	await physics_frame
	var initial_speed := piece.linear_velocity.length()
	var frames := 0
	while frames < 360:
		await physics_frame
		frames += 1
		if piece.linear_velocity.is_zero_approx() and frames > 2:
			break
	var result := {"mass": measured_mass, "initial_speed": initial_speed, "distance": piece.position.distance_to(start), "stop_time": frames / 60.0}
	piece.queue_free()
	await process_frame
	return result

func measure_variant_collision(variant: String, reference_impulse: Vector2) -> Dictionary:
	var projectile := AlkkagiPiece.new()
	projectile.setup(1, randi())
	projectile.position = Vector2(100, 680)
	root.add_child(projectile)
	var target := AlkkagiPiece.new()
	target.setup(2, randi())
	target.position = Vector2(250, 680)
	root.add_child(target)
	await physics_frame
	_configure_variant(projectile, variant)
	await physics_frame
	projectile.sleeping = false
	projectile.apply_launch_impulse(reference_impulse)
	var peak_target_speed := 0.0
	for frame in 30:
		await physics_frame
		peak_target_speed = maxf(peak_target_speed, target.linear_velocity.length())
	projectile.queue_free()
	target.queue_free()
	await process_frame
	return {"target_speed": peak_target_speed}

func _configure_variant(piece: AlkkagiPiece, variant: String) -> void:
	match variant:
		"tank":
			piece.apply_tank(1.25, 1.8)
		"king":
			piece.king_size_multiplier = 1.5
			piece.king_mass_multiplier = 2.0
			piece.transform_as("KING")
		"merge":
			piece.carried_count = 4
			piece.refresh_physics()

func measure_collision(impulse: Vector2) -> Dictionary:
	var projectile := AlkkagiPiece.new()
	projectile.setup(1, 8001)
	projectile.position = Vector2(100, 680)
	root.add_child(projectile)
	var target := AlkkagiPiece.new()
	target.setup(2, 8002)
	target.position = Vector2(250, 680)
	root.add_child(target)
	await physics_frame
	projectile.sleeping = false
	projectile.apply_central_impulse(impulse)
	var peak_target_speed := 0.0
	for frame in 30:
		await physics_frame
		peak_target_speed = maxf(peak_target_speed, target.linear_velocity.length())
	projectile.queue_free()
	target.queue_free()
	await process_frame
	return {"target_speed": peak_target_speed}

func estimate_slide_distance(initial_speed: float, damp: float) -> float:
	# Godot의 지수형 감속에 대한 비교용 연속 근사값입니다.
	return initial_speed / damp
