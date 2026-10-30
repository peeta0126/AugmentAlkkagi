extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func owned_piece(game: Node, player: int) -> AlkkagiPiece:
	for piece in game.get_pieces():
		if piece.owner_id == player:
			return piece
	return null

func run_test() -> void:
	var host: Node = load("res://scenes/main.tscn").instantiate()
	var guest: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(host)
	root.add_child(guest)
	await process_frame
	for game in [host, guest]:
		game.start_game()
		game.set_physics_process(false)
	host.augment_manager.acquire(host, 1, &"stasis")
	var stasis: AugmentEffect = host.augment_manager.effects[1][0]
	stasis.begin_active(host, 1)
	var frozen := owned_piece(host, 1)
	check(frozen.stasis_turns == 2 and frozen.freeze and frozen.invulnerable, "activation freezes and protects allies for two owner cycles")
	var attacker := owned_piece(host, 2)
	var defended_position := frozen.global_position
	var attack_origin := attacker.global_position
	attacker.global_position = defended_position + Vector2(100, 0)
	attacker.apply_launch_impulse(Vector2(-1000, 0))
	for frame in 30:
		await physics_frame
	check(frozen.global_position.distance_to(defended_position) < 0.01, "enemy impact does not move frozen defender")
	attacker.stop_motion()
	attacker.global_position = attack_origin
	host.resolve_turn()
	check(host.current_player == 2 and frozen.stasis_turns == 2, "activation turn preserves duration")
	host.state_machine.transition(GameStateMachine.State.PIECES_MOVING)
	host.resolve_turn()
	check(host.current_player == 1 and frozen.stasis_turns == 1, "first owner return decrements once")
	check(host.hud.pass_turn_panel.visible, "manual pass displayed on frozen owner turn")
	for viewport_size in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1600, 900)]:
		root.size = viewport_size
		await process_frame
		await process_frame
		var hud: GameHud = host.hud
		check(hud.pass_turn_panel.get_global_rect().position.y >= hud.active_skills_panel.get_global_rect().end.y or not hud.active_skills_panel.visible, "pass does not overlap active panel after resize")
		var scroll: ScrollContainer = hud.get_node("RightColumnScroll")
		check(scroll.get_global_rect().end.y <= hud.size.y, "right action column stays within resized viewport")
	host._on_piece_pressed(frozen)
	host.update_aim(frozen.position + Vector2(100, 0))
	host.fire_selected(frozen.position + Vector2(100, 0))
	check(not host.dragging and host.selected_piece == null and host.hud.power_bar.value == 0.0, "frozen drag, launch and charge blocked")
	# A non-consuming targeted skill remains available, including cancellation.
	host.augment_manager.acquire(host, 1, &"gravity_field")
	var gravity: AugmentEffect = host.augment_manager.effects[1][1]
	host._activate_skill(gravity)
	check(host.state_machine.current == GameStateMachine.State.SKILL_TARGETING and not host.hud.pass_turn_panel.visible, "frozen player can target active; pass hidden during targeting")
	host.cancel_active_skill()
	check(host.hud.pass_turn_panel.visible, "cancel targeting restores pass")
	host._activate_skill(gravity)
	host.confirm_board_position_skill(AlkkagiBoard.BOARD_RECT.get_center())
	check(host.state_machine.allows_aiming() and host.hud.pass_turn_panel.visible and gravity.uses_left == 0, "active application preserves manual pass")
	var many_skills: Array[Dictionary] = []
	for index in 12:
		many_skills.append({"id": "gravity_field", "text": "스킬 %d" % index})
	host.hud.set_active_skills(many_skills)
	await process_frame
	await process_frame
	check(host.hud.pass_turn_panel.get_global_rect().position.y >= host.hud.active_skills_panel.get_global_rect().end.y, "long skill list keeps pass below skills")
	var action_scroll: ScrollContainer = host.hud.get_node("RightColumnScroll")
	check(action_scroll.get_v_scroll_bar().max_value > action_scroll.size.y, "overflow action list is scrollable")
	var moving_states: Array = []
	host.state_machine.state_changed.connect(func(_old, state): moving_states.append(state))
	var revision: int = host.turn_revision
	var ended: int = host.augment_manager.completed_turns[1]
	host.hud.pass_turn_button.pressed.emit()
	check(host.current_player == 2 and host.augment_manager.completed_turns[1] == ended + 1, "button completes normal turn accounting")
	check(not GameStateMachine.State.PIECES_MOVING in moving_states, "pass starts no shot physics")
	check(not host.execute_pass_turn(1, revision), "duplicate old pass rejected")
	check(frozen.stasis_turns == 1 and frozen.freeze, "manual pass does not prematurely thaw")
	host.state_machine.transition(GameStateMachine.State.PIECES_MOVING)
	host.resolve_turn()
	check(frozen.stasis_turns == 0 and not frozen.freeze and not frozen.invulnerable, "second owner return restores physical state")
	host._on_piece_pressed(frozen)
	check(host.dragging, "thawed piece can aim again")
	host.cancel_aim()
	check(not host.hud.pass_turn_panel.visible, "thaw hides button")
	# Two instances exercise authenticated RPC dispatch and replicated status.
	var net: Node = load("res://tests/pass_turn_network_stub.gd").new()
	host.add_child(net)
	net.mode = net.Mode.HOST
	net.match_active = true
	net.peer_to_player = {22: 2}
	host.online_mode = true
	host.online_is_host = true
	host.local_player_id = 1
	host.current_player = 2
	host.state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
	for piece in host.get_pieces():
		piece.set_stasis(2)
		piece.stasis_cycle_based = true
	guest.online_mode = true
	guest.online_is_host = false
	guest.local_player_id = 2
	guest.turn_revision = 999
	guest.start_game_world()
	check(guest.turn_revision == 0, "new online world clears guest's previous local turn counter")
	var old_snapshot: Dictionary = host.create_network_snapshot()
	guest.apply_network_snapshot(host.create_network_snapshot())
	check(guest.hud.pass_turn_panel.visible, "guest sees own frozen turn")
	guest._on_piece_pressed(owned_piece(guest, 2))
	check(not guest.dragging and guest.hud.power_bar.value == 0.0, "guest cannot aim snapshot-frozen body")
	revision = host.turn_revision
	host.network_execute_shot(2, owned_piece(host, 2).piece_id, Vector2(80, 0))
	check(host.state_machine.allows_aiming(), "server rejects frozen shot")
	net.request_pass_turn(revision, 1)
	check(net.reply.accepted and host.current_player == 1, "host accepts guest pass")
	var client: Node = guest.network_manager
	client.mode = client.Mode.CLIENT
	client.match_active = true
	client.pending_pass_sequence = 1
	client._apply_pass_result(1, net.reply.accepted, net.reply.snapshot)
	check(guest.current_player == host.current_player and guest.turn_revision == host.turn_revision and not guest.hud.pass_turn_panel.visible, "response synchronizes turn and hides guest button")
	guest.apply_network_snapshot(old_snapshot)
	check(guest.current_player == host.current_player and guest.turn_revision == host.turn_revision, "late old-turn snapshot cannot undo pass")
	var after: int = host.turn_revision
	net.request_pass_turn(revision, 1)
	check(not net.reply.accepted and host.turn_revision == after, "duplicate sequence cannot end another turn")
	net.request_pass_turn(after, 2)
	check(not net.reply.accepted, "opponent request rejected")
	check(net._host_process_pass(1, after), "host can manually pass with both sides frozen")
	check(host.current_player == 2 and host.turn_revision == after + 1, "both frozen cause one explicit transition only")
	net.request_pass_turn(revision, 3)
	check(not net.reply.accepted, "old turn token rejected on same player's later turn")
	net.sender = 99
	net.request_pass_turn(host.turn_revision, 4)
	check(host.current_player == 2, "unknown peer cannot mutate turn")
	guest.apply_network_snapshot(host.create_network_snapshot())
	client.pending_pass_sequence = 5
	guest._refresh_pass_turn_hud()
	check(not guest.hud.pass_turn_panel.visible, "pending request suppresses repeated clicks")
	client._tick_pass_request(client.ACTIVE_REQUEST_TIMEOUT + 0.1)
	check(client.pending_pass_sequence == 0 and guest.hud.pass_turn_panel.visible, "timeout unlocks retry")
	client.pending_pass_sequence = 6
	client._apply_pass_result(5, true, net.reply.snapshot)
	check(client.pending_pass_sequence == 6, "late response cannot complete newer request")
	client._apply_pass_result(6, false, host.create_network_snapshot())
	check(client.pending_pass_sequence == 0 and guest.hud.pass_turn_panel.visible, "rejection unlocks retry")
	for state in [GameStateMachine.State.PIECES_MOVING, GameStateMachine.State.AUGMENT_SELECTION, GameStateMachine.State.TURN_RESOLUTION, GameStateMachine.State.PIECE_PLACEMENT, GameStateMachine.State.GAME_OVER]:
		host.state_machine.transition(state)
		check(not host.can_pass_turn(2), "pass denied outside action selection")
	host.state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
	owned_piece(host, 2).clear_temporary_status()
	check(not host.can_pass_turn(2), "one launchable piece suppresses pass")
	for piece in host.get_pieces():
		if piece.owner_id == 2:
			piece.queue_free()
	check(not host.can_pass_turn(2), "empty army never qualifies as frozen")
	client.mode = client.Mode.OFFLINE
	net.mode = net.Mode.OFFLINE
	host.queue_free()
	guest.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: stasis manual pass, actives, duration/thaw, authority, replication, duplicate/stale/timeout/rejection and phase guards")
	quit(failures)
