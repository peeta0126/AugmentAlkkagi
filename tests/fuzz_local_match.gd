## 무작위 증강·무작위 발사로 로컬 대전을 많이 돌려 멈춤·스크립트 오류를 찾는 점검 도구(테스트 모음에는 넣지 않음)
extends SceneTree

const MAX_TURNS := 60
const STUCK_PHYSICS_FRAMES := 60 * 25

var failures := 0
var rng := RandomNumberGenerator.new()

func _init() -> void:
	call_deferred("run")

func report(message: String) -> void:
	failures += 1
	print("FUZZ-FAIL: " + message)

func run() -> void:
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 8
	var seed_start := 1
	var seed_count := 20
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seeds="):
			var parts := argument.trim_prefix("--seeds=").split("-")
			seed_start = int(parts[0])
			seed_count = int(parts[1]) - seed_start + 1
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	for seed_value in range(seed_start, seed_start + seed_count):
		await play_match(game, seed_value)
	print("FUZZ done failures=%d" % failures)
	quit(failures)

func play_match(game: Node, seed_value: int) -> void:
	rng.seed = seed_value
	game.starting_piece_count = rng.randi_range(3, 5)
	game.clear_world()
	game.augment_manager.reset_match()
	game.reset_runtime_effects()
	game.start_game_world()
	await process_frame
	var catalog: Array = game.augment_manager.CATALOG
	var names := []
	for player_id in [1, 2]:
		var count := rng.randi_range(1, 3)
		var pool := catalog.duplicate()
		pool.shuffle()
		for index in count:
			game.augment_manager.acquire(game, player_id, pool[index].id)
			names.append("%d:%s" % [player_id, pool[index].id])
	var tag := "seed=%d aug=%s" % [seed_value, ",".join(names)]
	var turns := 0
	while turns < MAX_TURNS:
		var state: int = game.state_machine.current
		if state == GameStateMachine.State.GAME_OVER:
			return
		if state in [GameStateMachine.State.INITIAL_AUGMENT_SELECTION, GameStateMachine.State.AUGMENT_SELECTION]:
			if game.current_choices.is_empty():
				report("%s empty augment choices" % tag)
				return
			game._choose_augment(game.current_choices[0].id)
			await process_frame
			continue
		if state != GameStateMachine.State.PLAYER_AIMING:
			var waited := 0
			while game.state_machine.current in [GameStateMachine.State.PIECES_MOVING, GameStateMachine.State.TURN_RESOLUTION, GameStateMachine.State.SKILL_TARGETING] and waited < STUCK_PHYSICS_FRAMES:
				await physics_frame
				waited += 1
			if waited >= STUCK_PHYSICS_FRAMES:
				report("%s stuck in state %s after turn %d" % [tag, GameStateMachine.State.keys()[game.state_machine.current], turns])
				return
			continue
		turns += 1
		if rng.randf() < 0.35:
			await try_active(game, tag)
			if game.state_machine.current != GameStateMachine.State.PLAYER_AIMING:
				continue
		var mine: Array = []
		for piece in game.get_pieces():
			if piece.owner_id == game.current_player and game.piece_can_launch(piece):
				mine.append(piece)
		if mine.is_empty():
			if game.can_pass_turn(game.current_player):
				game.execute_pass_turn(game.current_player, game.turn_revision)
				await process_frame
				continue
			report("%s no launchable piece and cannot pass (player %d)" % [tag, game.current_player])
			return
		var piece: AlkkagiPiece = mine[rng.randi_range(0, mine.size() - 1)]
		game._on_piece_pressed(piece)
		var angle := rng.randf() * TAU
		game.fire_selected(piece.global_position + Vector2.RIGHT.rotated(angle) * rng.randf_range(20.0, 160.0))
		await physics_frame
	# 60턴 안에 안 끝나는 것은 오류가 아니다(서로 못 맞히는 경우).

func try_active(game: Node, tag: String) -> void:
	var player: int = game.current_player
	var usable: Array = []
	for effect: AugmentEffect in game.augment_manager.active_effects(player):
		if effect.can_activate(game, player):
			usable.append(effect)
	if usable.is_empty():
		return
	var effect: AugmentEffect = usable[rng.randi_range(0, usable.size() - 1)]
	game._activate_skill(effect)
	await process_frame
	var guard := 0
	while game.state_machine.current == GameStateMachine.State.SKILL_TARGETING and guard < 6:
		guard += 1
		var pieces: Array = game.get_pieces()
		var target: AlkkagiPiece = pieces[rng.randi_range(0, pieces.size() - 1)]
		var handled := effect.on_piece_target(game, player, target)
		if not handled:
			handled = effect.on_position_target(game, player, Vector2(rng.randf_range(80.0, 420.0), rng.randf_range(80.0, 460.0)))
		await process_frame
	if game.state_machine.current == GameStateMachine.State.SKILL_TARGETING:
		game.cancel_active_skill()
