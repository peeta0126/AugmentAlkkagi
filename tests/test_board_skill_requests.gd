extends SceneTree

var failures := 0
func _init() -> void:
	call_deferred("run_test")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func run_test() -> void:
	var host: Node = load("res://scenes/main.tscn").instantiate()
	var guest: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(host)
	root.add_child(guest)
	await process_frame
	var net: Node = load("res://tests/board_skill_network_stub.gd").new()
	host.add_child(net)
	net.mode = net.Mode.HOST
	net.match_active = true
	net.peer_to_player = {22: 2}
	for game in [host, guest]:
		game.clear_world()
		game.augment_manager.reset_match()
		game.start_game_world()
		game.set_physics_process(false)
		game.current_player = 2
		game.state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
		game.augment_manager.acquire(game, 2, &"gravity_field")
	host.online_mode = true
	host.online_is_host = true
	guest.online_mode = true
	guest.online_is_host = false
	guest.local_player_id = 2
	var client: Node = guest.network_manager
	client.mode = net.Mode.CLIENT
	client.match_active = true
	var effect: GravityFieldAugmentEffect = guest.augment_manager.effects[2][0]
	guest.begin_skill_targeting(effect, 2)
	guest.network_show_waiting("waiting")
	client.pending_active_sequence = 1
	net.request_active_skill("gravity_field", [], Vector2(-1, -1), 1)
	check(not net.reply.accepted, "invalid position returns rejection")
	client._apply_active_result(1, net.reply.accepted, net.reply.reason, net.reply.snapshot)
	check(guest.state_machine.allows_aiming() and guest.active_skill == null and guest.screen_root is GameHud, "rejection clears waiting and permits retry")
	check(effect.uses_left == 1, "rejection does not consume use")
	guest.begin_skill_targeting(effect, 2)
	guest.network_show_waiting("waiting")
	client.pending_active_sequence = 2
	var center := AlkkagiBoard.BOARD_RECT.get_center()
	net.request_active_skill("gravity_field", [], center, 2)
	check(net.reply.accepted, "host approves valid client gravity")
	guest.apply_network_snapshot(net.reply.snapshot)
	check(guest.state_machine.current == GameStateMachine.State.SKILL_TARGETING, "ordinary snapshot reproduces the pending targeting condition")
	client._apply_active_result(2, true, "", net.reply.snapshot)
	check(effect.has_center and effect.center_position == center and effect.uses_left == 0, "approved position and usage reach client")
	check(guest.state_machine.allows_aiming() and guest.screen_root is GameHud and guest.active_skill == null, "approval escapes targeting and waiting")
	check(guest.board.field_visuals.has("gravity_2"), "approved field visual reaches client")
	net.request_active_skill("gravity_field", [], center + Vector2(30, 0), 2)
	check(net.reply.accepted and net.reply.snapshot.effects == host.create_network_snapshot().effects, "duplicate returns cached result without applying again")
	check((host.augment_manager.effects[2][0] as GravityFieldAugmentEffect).center_position == center, "duplicate cannot move field")
	client.pending_active_sequence = 3
	guest.network_show_waiting("waiting")
	client._tick_active_request(net.ACTIVE_REQUEST_TIMEOUT + 0.1)
	check(client.pending_active_sequence == 0 and guest.screen_root is GameHud and guest.state_machine.allows_aiming(), "missing response times out and unlocks")
	client.pending_active_sequence = 4
	client._apply_active_result(3, true, "", net.reply.snapshot)
	check(client.pending_active_sequence == 4, "late result cannot complete newer request")
	client.pending_active_sequence = 0
	net.request_active_skill("gravity_field", ["bad"], center, 3)
	check(not net.reply.accepted and not str(net.reply.reason).is_empty(), "malformed request returns reason")
	host.current_player = 1
	net.request_active_skill("gravity_field", [], center, 4)
	check(not net.reply.accepted, "wrong-turn request returns rejection")
	guest.state_machine.transition(GameStateMachine.State.PIECES_MOVING)
	client.pending_active_sequence = 5
	client._tick_active_request(net.ACTIVE_REQUEST_TIMEOUT + 0.1)
	check(guest.state_machine.current == GameStateMachine.State.PIECES_MOVING, "timeout preserves replicated physics state")
	# Host-local validation uses the same authority checks without a remote RPC.
	host.current_player = 1
	host.augment_manager.acquire(host, 1, &"gravity_field")
	var ids: Array[int] = []
	check(net._host_process_active(1, &"gravity_field", ids, center, 5), "host can install gravity")
	check(host.state_machine.allows_aiming(), "host installation preserves aiming")
	# Wall shares only target dispatch, retaining its own validation and geometry.
	host.augment_manager.acquire(host, 1, &"wall_maria")
	net.active_response_context = true
	check(not net._host_process_active(1, &"wall_maria", ids, Vector2(-1, -1), 6), "invalid wall rejected")
	check(net._host_process_active(1, &"wall_maria", ids, center, 7), "valid wall still installs")
	check(host.temporary_walls.size() == 1, "one wall created")
	client.mode = net.Mode.OFFLINE
	net.mode = net.Mode.OFFLINE
	host.queue_free()
	guest.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: board requests approval/rejection, duplicate, timeout, stale response, host gravity and wall regression")
	quit(failures)

