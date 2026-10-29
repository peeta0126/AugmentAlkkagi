extends SceneTree

var failures := 0
func _init() -> void:
	call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func check_zero(game: Node, label: String) -> void:
	check(game.hud.power_bar.value == 0.0, label + " range value is zero")
	check(game.hud._power_number.text == "0%", label + " percentage is zero")
	check(not game.hud._power_fill_panel.visible, label + " fill is empty")
func aim(game: Node, fraction: float) -> Vector2:
	var piece: AlkkagiPiece
	for candidate in game.get_pieces():
		if candidate.owner_id == game.current_player:
			piece = candidate
			break
	game._on_piece_pressed(piece)
	var profile: Dictionary = game._current_shot_profile()
	var pointer := piece.global_position - Vector2(GameplayRules.BALANCE.drag_distance * float(profile.max_drag_multiplier) * fraction, 0)
	game.update_aim(pointer)
	check(absf(game.hud.power_bar.value - fraction * 100.0) < 0.1, "drag updates normalized power")
	return pointer
func run_test() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game()
	game.set_physics_process(false)
	check_zero(game, "initial HUD")
	var pointer := aim(game, 0.62)
	game.cancel_aim()
	check_zero(game, "cancel")
	check(not game.dragging and game.selected_piece == null, "cancel clears input state")
	game.update_aim(pointer)
	check_zero(game, "stale aim event")
	for online in [false, true]:
		game.online_mode = online
		game.online_is_host = online
		game.local_player_id = 1
		game.current_player = 1
		for fraction in [0.62, 0.3, 0.9]:
			game.state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
			pointer = aim(game, fraction)
			game.fire_selected(pointer)
			check_zero(game, "immediate launch")
			check(not game.dragging and game.selected_piece == null, "launch clears input state")
			game.update_aim(pointer)
			await process_frame
			check_zero(game, "moving")
			game.resolve_turn()
			check_zero(game, "next turn HUD")
			game.current_player = 1
	game.online_mode = false
	game.current_player = 1
	game.state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
	game.augment_manager.acquire(game, 1, &"triple_shot")
	var triple: AugmentEffect
	for effect in game.augment_manager.effects[1]:
		if effect.definition.id == &"triple_shot":
			triple = effect
	if triple:
		triple.activate_immediate(game, 1)
		game.state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
		pointer = aim(game, 0.5)
		game.fire_selected(pointer)
		check_zero(game, "augmented launch")
	# Exercise client submission without sending an external GD-Sync packet.
	game.online_mode = true
	game.online_is_host = false
	game.current_player = 2
	game.local_player_id = 2
	game.state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
	pointer = aim(game, 0.62)
	game.fire_selected(pointer)
	check_zero(game, "client submission")
	var snapshot: Dictionary = game.create_network_snapshot()
	for state in [GameStateMachine.State.PIECES_MOVING, GameStateMachine.State.PLAYER_AIMING]:
		snapshot["state"] = int(state)
		game.apply_network_snapshot(snapshot)
		check_zero(game, "client approval or rejection snapshot")
	game.build_hud()
	check_zero(game, "rebuilt HUD")
	game.online_mode = false
	game.start_game()
	check_zero(game, "restart")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: power zero on initialization, launch, cancel, augmented shot, client snapshots, rebuild and restart")
	quit(failures)
