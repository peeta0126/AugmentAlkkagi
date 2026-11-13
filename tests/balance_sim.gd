## 증강 밸런스 점검 도구(테스트 모음에는 넣지 않음): 단순한 봇 둘이 로컬 대전을 많이 치러 증강별 승률을 낸다.
## 사용: godot --headless --script res://tests/balance_sim.gd -- --matchups=none:none,triple_shot:none --games=20 --seed=1
##   조합은 `증강+증강:증강` 꼴(왼쪽이 흑돌, 오른쪽이 백돌), 증강 없음은 none. 게임마다 선공을 번갈아 정한다.
extends SceneTree

const MAX_TURNS := 60
const STUCK_PHYSICS_FRAMES := 60 * 25

var rng := RandomNumberGenerator.new()

func _init() -> void:
	call_deferred("run")

func run() -> void:
	Engine.time_scale = 8.0
	Engine.max_physics_steps_per_frame = 16
	var matchups: PackedStringArray = []
	var games := 10
	var seed_value := 1
	var piece_count := 5
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--matchups="):
			matchups = argument.trim_prefix("--matchups=").split(",")
		elif argument.begins_with("--games="):
			games = int(argument.trim_prefix("--games="))
		elif argument.begins_with("--seed="):
			seed_value = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--pieces="):
			piece_count = int(argument.trim_prefix("--pieces="))
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	for matchup in matchups:
		var sides := matchup.split(":")
		var wins := {1: 0, 2: 0, 0: 0}
		var first_wins := 0
		var turn_sum := 0
		for index in games:
			rng.seed = seed_value * 1000 + index
			var first := 1 if index % 2 == 0 else 2
			var outcome := await play_game(game, sides[0], sides[1], first, piece_count)
			wins[outcome.winner] += 1
			if outcome.winner == first:
				first_wins += 1
			turn_sum += outcome.turns
		print("RESULT %s | p1=%d p2=%d draw=%d | first_mover_wins=%d/%d | avg_turns=%.1f" % [matchup, wins[1], wins[2], wins[0], first_wins, games, float(turn_sum) / games])
	quit(0)

func load_augments(game: Node, player_id: int, spec: String) -> void:
	if spec == "none" or spec == "":
		return
	for name in spec.split("+"):
		game.augment_manager.acquire(game, player_id, StringName(name))

func play_game(game: Node, spec1: String, spec2: String, first: int, piece_count: int) -> Dictionary:
	game.starting_piece_count = piece_count
	game.clear_world()
	game.augment_manager.reset_match()
	game.reset_runtime_effects()
	game.start_game_world()
	await process_frame
	load_augments(game, 1, spec1)
	load_augments(game, 2, spec2)
	game.developer_mode_active = true  # 3·6라운드 증강 선택이 끼어들어 조합이 바뀌지 않게 한다.
	game.current_player = first
	game.build_hud()
	var turns := 0
	var idle := 0
	while turns < MAX_TURNS:
		var state: int = game.state_machine.current
		if state == GameStateMachine.State.GAME_OVER:
			return {"winner": game.network_winner if game.network_winner != 0 else winner_by_count(game), "turns": turns}
		if state != GameStateMachine.State.PLAYER_AIMING:
			var waited := 0
			while game.state_machine.current in [GameStateMachine.State.PIECES_MOVING, GameStateMachine.State.TURN_RESOLUTION, GameStateMachine.State.SKILL_TARGETING] and waited < STUCK_PHYSICS_FRAMES:
				await physics_frame
				waited += 1
				if waited % 300 == 0 and OS.get_cmdline_user_args().has('--verbose'):
					print('waiting state=', GameStateMachine.State.keys()[game.state_machine.current], ' waited=', waited, ' pending=', game.augment_manager.has_pending_action())
			if waited >= STUCK_PHYSICS_FRAMES:
				push_error("stuck: %s vs %s" % [spec1, spec2])
				return {"winner": 0, "turns": turns}
			if waited == 0:
				await physics_frame  # 기다릴 상태가 아니면 한 프레임 넘겨 바쁜 반복을 막는다.
				idle += 1
				if idle > 600:
					push_error("idle in state %s: %s vs %s" % [GameStateMachine.State.keys()[game.state_machine.current], spec1, spec2])
					return {"winner": 0, "turns": turns}
			continue
		turns += 1
		if OS.get_cmdline_user_args().has('--verbose'):
			print('turn ', turns, ' p', game.current_player, ' counts ', game.count_owner(1), '/', game.count_owner(2), ' t=', Time.get_ticks_msec())
		await bot_turn(game)
	return {"winner": winner_by_count(game), "turns": turns}

func winner_by_count(game: Node) -> int:
	var a: int = game.count_owner(1)
	var b: int = game.count_owner(2)
	if a > b:
		return 1
	if b > a:
		return 2
	return 0

func nearest_enemy(game: Node, from: Vector2, player: int) -> AlkkagiPiece:
	var best: AlkkagiPiece = null
	for piece in game.get_pieces():
		if piece.owner_id != player and (best == null or piece.global_position.distance_to(from) < best.global_position.distance_to(from)):
			best = piece
	return best

# 봇: 쓸 수 있는 능력을 어림 규칙으로 쓰고, 가장 가까운 (내 돌, 상대 돌) 쌍을 흔들림을 섞어 조준한다.
func bot_turn(game: Node) -> void:
	var player: int = game.current_player
	var enemy_player := 2 if player == 1 else 1
	for effect: AugmentEffect in game.augment_manager.active_effects(player):
		if game.state_machine.current != GameStateMachine.State.PLAYER_AIMING:
			break
		if not effect.can_activate(game, player):
			continue
		if not bot_wants(game, effect, player):
			continue
		game._activate_skill(effect)
		await process_frame
		var guard := 0
		while game.state_machine.current == GameStateMachine.State.SKILL_TARGETING and guard < 6:
			guard += 1
			var handled := false
			var mine := own_pieces(game, player)
			if not mine.is_empty():
				# 가장 앞(상대 쪽)에 있는 내 돌을 대상으로 삼는다.
				mine.sort_custom(func(a, b): return a.global_position.distance_to(nearest_enemy(game, a.global_position, player).global_position) < b.global_position.distance_to(nearest_enemy(game, b.global_position, player).global_position))
				handled = effect.on_piece_target(game, player, mine[0])
			if not handled:
				var center: Vector2 = AlkkagiBoard.BOARD_RECT.get_center()
				handled = effect.on_position_target(game, player, center + Vector2(rng.randf_range(-120.0, 120.0), rng.randf_range(-100.0, 100.0)))
			await process_frame
		if game.state_machine.current == GameStateMachine.State.SKILL_TARGETING:
			game.cancel_active_skill()
		if game.state_machine.current != GameStateMachine.State.PLAYER_AIMING:
			return
	var mine := own_pieces(game, player)
	if mine.is_empty():
		if game.can_pass_turn(player):
			game.execute_pass_turn(player, game.turn_revision)
		return
	var best_piece: AlkkagiPiece = mine[0]
	var best_target: AlkkagiPiece = null
	var best_distance := INF
	for piece in mine:
		var target := nearest_enemy(game, piece.global_position, player)
		if target == null:
			continue
		var distance: float = piece.global_position.distance_to(target.global_position) + rng.randf_range(0.0, 40.0)
		if distance < best_distance:
			best_distance = distance
			best_piece = piece
			best_target = target
	if best_target == null:
		return
	var profile: Dictionary = game._current_shot_profile()
	var max_drag: float = GameplayRules.BALANCE.drag_distance * float(profile.max_drag_multiplier)
	var direction: Vector2 = (best_target.global_position - best_piece.global_position).normalized().rotated(deg_to_rad(rng.randfn(0.0, 4.0)))
	var pull := clampf(best_distance * 0.45 + 30.0, 40.0, max_drag) * rng.randf_range(0.85, 1.0)
	var v := OS.get_cmdline_user_args().has('--verbose')
	if v: print('  aim piece=', best_piece.piece_id, ' dir=', direction, ' pull=', pull)
	game._on_piece_pressed(best_piece)
	if v: print('  pressed')
	game.fire_selected(best_piece.global_position - direction * pull)
	if v: print('  fired state=', GameStateMachine.State.keys()[game.state_machine.current])
	await physics_frame
	if v: print('  after frame')

func own_pieces(game: Node, player: int) -> Array:
	var result: Array = []
	for piece in game.get_pieces():
		if piece.owner_id == player and game.piece_can_launch(piece):
			result.append(piece)
	return result

# 능력별 어림 사용 규칙. 사람이 쓰는 방식과 완전히 같지는 않다.
func bot_wants(game: Node, effect: AugmentEffect, player: int) -> bool:
	var enemy := 2 if player == 1 else 1
	var mine: int = game.count_owner(player)
	var theirs: int = game.count_owner(enemy)
	match effect.definition.id:
		&"coup":
			return mine + 1 < theirs
		&"stasis":
			return mine < theirs and rng.randf() < 0.5
		&"piggyback":
			return mine >= 3 and rng.randf() < 0.4
		&"blind", &"stealth":
			return rng.randf() < 0.5
		&"earthquake", &"wish", &"triple_shot", &"gravity_field", &"wall_maria", &"snowball", &"wizard", &"greatsword", &"tank", &"janggi":
			return rng.randf() < 0.7
	return rng.randf() < 0.5
