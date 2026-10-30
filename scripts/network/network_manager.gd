class_name AlkkagiNetworkManager
extends Node

signal lobby_updated(data: Dictionary)
signal connection_message(text: String, is_error: bool)
signal session_ended(reason: String)

const SNAPSHOT_INTERVAL := 0.05
const SNAPSHOT_HEARTBEAT := 1.0
const SNAPSHOT_REPEATS := 2
const SNAPSHOT_IDLE_GAP := 0.3
const ACTIVE_REQUEST_TIMEOUT := 8.0
# v4 separates reliable world extras from throttled movement snapshots.
const PROTOCOL_VERSION := 6
const ROOM_PREFIX := "AA-"
const ROOM_CODE_LENGTH := 6
const ROOM_CREATE_ATTEMPTS := 5

enum Mode { OFFLINE, HOST, CLIENT }

var mode := Mode.OFFLINE
var local_player_id := 0
var peer_to_player: Dictionary = {1: 1}
var ready_state: Dictionary = {1: false, 2: false}
var connected_players: Dictionary = {1: true, 2: false}
var piece_count := GameplayRules.DEFAULT_PIECES
var refresh_mode := false
var chaos_mode := false
var match_active := false
var offers: Dictionary = {}
var selection_context: Dictionary = {}
var active_selection_stage := 0
var selection_completed: Dictionary = {1: false, 2: false}
var selection_pick_counts: Dictionary = {1: 0, 2: 0}
var selection_pick_targets: Dictionary = {1: 1, 2: 1}
var selection_refresh_used: Dictionary = {1: false, 2: false}
var pending_choices: Dictionary = {}
var placement_completed: Dictionary = {1: false, 2: false}
var last_sequences: Dictionary = {}
var pending_active_sequence := 0
var pending_pass_sequence := 0
var pending_pass_seconds := 0.0
var pending_active_seconds := 0.0
var active_response_context := false
var active_response_reason := ""
var active_results: Dictionary = {}
var local_sequence := 0
var snapshot_elapsed := 0.0
var heartbeat_elapsed := 0.0
var last_fast_bytes := PackedByteArray()
var last_slow_bytes := PackedByteArray()
var fast_repeats := 0
var pending_extras: Dictionary = {}
var snapshot_metrics: Dictionary = {}
var last_snapshot_received_usec := 0
var shutting_down := false
var room_code := ""
var room_create_attempts := 0
var gdsync_host_id := -1
var gdsync_connected := false

func _ready() -> void:
	name = "NetworkManager"
	GDSync.lobby_created.connect(_on_gdsync_lobby_created)
	GDSync.lobby_creation_failed.connect(_on_gdsync_lobby_creation_failed)
	GDSync.lobby_joined.connect(_on_gdsync_lobby_joined)
	GDSync.lobby_join_failed.connect(_on_gdsync_lobby_join_failed)
	GDSync.client_joined.connect(_on_gdsync_client_joined)
	GDSync.client_left.connect(_on_gdsync_client_left)
	GDSync.host_changed.connect(_on_gdsync_host_changed)
	GDSync.connected.connect(_on_gdsync_connected)
	GDSync.disconnected.connect(_on_gdsync_disconnected)
	GDSync.expose_func(request_lobby_ready, ENUMS.EXPOSE_PERMISSION.CLIENT)
	GDSync.expose_func(request_shot, ENUMS.EXPOSE_PERMISSION.CLIENT)
	GDSync.expose_func(request_pass_turn, ENUMS.EXPOSE_PERMISSION.CLIENT)
	GDSync.expose_func(receive_pass_turn_result, ENUMS.EXPOSE_PERMISSION.HOST)
	GDSync.expose_func(request_augment_choice, ENUMS.EXPOSE_PERMISSION.CLIENT)
	GDSync.expose_func(request_augment_refresh, ENUMS.EXPOSE_PERMISSION.CLIENT)
	GDSync.expose_func(request_piece_placement, ENUMS.EXPOSE_PERMISSION.CLIENT)
	GDSync.expose_func(request_placement_complete, ENUMS.EXPOSE_PERMISSION.CLIENT)
	GDSync.expose_func(request_active_skill, ENUMS.EXPOSE_PERMISSION.CLIENT)
	GDSync.expose_func(receive_lobby, ENUMS.EXPOSE_PERMISSION.HOST)
	GDSync.expose_func(receive_return_lobby, ENUMS.EXPOSE_PERMISSION.HOST)
	GDSync.expose_func(receive_projectile, ENUMS.EXPOSE_PERMISSION.HOST)
	GDSync.expose_func(receive_piece_sound, ENUMS.EXPOSE_PERMISSION.HOST)
	GDSync.expose_func(receive_augment_offer, ENUMS.EXPOSE_PERMISSION.HOST)
	GDSync.expose_func(receive_augment_granted, ENUMS.EXPOSE_PERMISSION.HOST)
	GDSync.expose_func(receive_placement_state, ENUMS.EXPOSE_PERMISSION.HOST)
	GDSync.expose_func(receive_world_start, ENUMS.EXPOSE_PERMISSION.HOST)
	GDSync.expose_func(receive_selection_complete, ENUMS.EXPOSE_PERMISSION.HOST)
	GDSync.expose_func(receive_active_skill_rejected, ENUMS.EXPOSE_PERMISSION.HOST)
	GDSync.expose_func(receive_active_skill_result, ENUMS.EXPOSE_PERMISSION.HOST)
	GDSync.expose_func(receive_snapshot, ENUMS.EXPOSE_PERMISSION.HOST)
	GDSync.expose_func(receive_world_extras, ENUMS.EXPOSE_PERMISSION.HOST)
	_reset_snapshot_cache()

func game() -> Node:
	return get_parent()

func _selection_debug(message: String) -> void:
	if OS.is_debug_build():
		print("[augment-selection] %s" % message)

func _selection_reject(reason: String, player_id: int, stage: int, augment_id: StringName = &"") -> void:
	if OS.is_debug_build():
		push_warning("[augment-selection] rejected: %s (player=%d stage=%d active_stage=%d augment=%s completed=%s pending=%s)" % [reason, player_id, stage, active_selection_stage, augment_id, selection_completed, pending_choices])

func create_online_room(preferred_code: String = "") -> Error:
	if not gdsync_connected:
		connection_message.emit("GD-Sync 서버에 아직 연결되지 않았습니다.", true)
		return ERR_UNAVAILABLE
	shutdown(false)
	mode = Mode.HOST
	local_player_id = 1
	room_create_attempts = 0
	_reset_lobby_state()
	_create_online_room_attempt(preferred_code)
	return OK

func _create_online_room_attempt(preferred_code: String = "") -> void:
	room_create_attempts += 1
	room_code = preferred_code if preferred_code.length() == ROOM_CODE_LENGTH and preferred_code.is_valid_int() else "%06d" % randi_range(0, 999999)
	connection_message.emit("온라인 방 %s 생성 중…" % room_code, false)
	GDSync.lobby_create(ROOM_PREFIX + room_code, "", false, 2, {"protocol": PROTOCOL_VERSION}, {})

func join_online_room(code: String) -> Error:
	var normalized := code.strip_edges()
	if normalized.length() != ROOM_CODE_LENGTH or not normalized.is_valid_int():
		connection_message.emit("6자리 숫자 방 코드를 입력하세요.", true)
		return ERR_INVALID_PARAMETER
	if not gdsync_connected:
		connection_message.emit("GD-Sync 서버에 아직 연결되지 않았습니다.", true)
		return ERR_UNAVAILABLE
	shutdown(false)
	last_snapshot_received_usec = 0
	mode = Mode.CLIENT
	local_player_id = 2
	room_code = normalized
	_reset_lobby_state()
	connected_players[1] = false
	connection_message.emit("온라인 방 %s 참가 중…" % room_code, false)
	GDSync.lobby_join(ROOM_PREFIX + room_code)
	return OK

func _reset_lobby_state() -> void:
	last_sequences.clear()
	active_results.clear()
	pending_active_sequence = 0
	pending_pass_sequence = 0
	local_sequence = 0
	peer_to_player.clear()
	ready_state = {1: false, 2: false}
	connected_players = {1: true, 2: false}
	match_active = false
	refresh_mode = false
	chaos_mode = false
	_reset_selection_state()
	_reset_snapshot_cache()
	gdsync_host_id = -1

func shutdown(notify: bool = true) -> void:
	var was_online := mode != Mode.OFFLINE
	shutting_down = true
	if not GDSync.lobby_get_name().is_empty():
		GDSync.lobby_leave()
	mode = Mode.OFFLINE
	local_player_id = 0
	match_active = false
	last_snapshot_received_usec = 0
	last_sequences.clear()
	active_results.clear()
	pending_active_sequence = 0
	pending_pass_sequence = 0
	local_sequence = 0
	peer_to_player = {1: 1}
	ready_state = {1: false, 2: false}
	connected_players = {1: true, 2: false}
	_reset_selection_state()
	_reset_snapshot_cache()
	refresh_mode = false
	chaos_mode = false
	room_code = ""
	room_create_attempts = 0
	gdsync_host_id = -1
	shutting_down = false
	if notify and was_online:
		session_ended.emit("네트워크 방에서 나왔습니다.")

func _reset_selection_state() -> void:
	offers.clear()
	selection_context.clear()
	pending_choices.clear()
	active_selection_stage = 0
	selection_completed = {1: false, 2: false}
	selection_pick_counts = {1: 0, 2: 0}
	selection_pick_targets = {1: 1, 2: 1}
	selection_refresh_used = {1: false, 2: false}
	placement_completed = {1: false, 2: false}

func is_online() -> bool:
	return mode != Mode.OFFLINE

func is_host() -> bool:
	return mode == Mode.HOST

func get_room_code() -> String:
	return room_code

func set_ready(value: bool) -> void:
	if is_host():
		ready_state[1] = value
		_broadcast_lobby()
	elif mode == Mode.CLIENT and gdsync_host_id >= 0:
		GDSync.call_func_on(gdsync_host_id, request_lobby_ready, value, PROTOCOL_VERSION)

func set_piece_count(value: int) -> void:
	if not is_host() or match_active:
		return
	piece_count = GameplayRules.clamp_piece_count(value)
	_broadcast_lobby()

func set_modes(refresh_enabled: bool, chaos_enabled: bool) -> void:
	if not is_host() or match_active:
		return
	refresh_mode = refresh_enabled
	chaos_mode = chaos_enabled
	# Any host-side rules change invalidates the guest's previous acknowledgement.
	ready_state[2] = false
	_broadcast_lobby()

func can_start() -> bool:
	return is_host() and bool(connected_players[1]) and bool(connected_players[2]) and bool(ready_state[1]) and bool(ready_state[2])

func start_match() -> bool:
	if not can_start():
		connection_message.emit("두 플레이어가 접속하고 모두 준비해야 합니다.", true)
		return false
	match_active = true
	_reset_snapshot_cache()
	placement_completed = {1: false, 2: false}
	game().network_prepare_match(true, 1, piece_count, refresh_mode, chaos_mode)
	GDSync.call_func(receive_world_start, piece_count, refresh_mode, chaos_mode)
	game().network_start_world(piece_count)
	return true

func return_to_lobby() -> void:
	if not is_host():
		return
	match_active = false
	_reset_snapshot_cache()
	placement_completed = {1: false, 2: false}
	ready_state = {1: false, 2: false}
	GDSync.call_func(receive_return_lobby)
	game()._show_network_lobby()
	_broadcast_lobby()

func receive_return_lobby() -> void:
	match_active = false
	_reset_snapshot_cache()
	placement_completed = {1: false, 2: false}
	game()._show_network_lobby()

func _start_selection(initial: bool, resume_player: int, completed_round: int) -> void:
	if not is_host():
		_selection_reject("selection start requested by non-host", local_player_id, active_selection_stage)
		return
	active_selection_stage += 1
	offers.clear()
	pending_choices.clear()
	selection_completed = {1: false, 2: false}
	selection_pick_counts = {1: 0, 2: 0}
	selection_refresh_used = {1: false, 2: false}
	var requested_picks := 2 if chaos_mode else 1
	for player_id in [1, 2]:
		var available_slots: int = GameplayRules.MAX_AUGMENTS_PER_PLAYER - game().augment_manager.owned[player_id].size()
		selection_pick_targets[player_id] = mini(requested_picks, available_slots)
		selection_completed[player_id] = available_slots <= 0
	selection_context = {"initial": initial, "resume": resume_player, "round": completed_round}
	_selection_debug("stage %d started (initial=%s round=%d resume=%d)" % [active_selection_stage, initial, completed_round, resume_player])
	_begin_selection(2, initial, resume_player)
	_begin_selection(1, initial, resume_player)

func _begin_selection(player_id: int, initial: bool, resume_player: int) -> void:
	if not is_host():
		_selection_reject("offer generation requested by non-host", player_id, active_selection_stage)
		return
	if bool(selection_completed.get(player_id, false)):
		return
	var definitions: Array[AugmentDefinition] = game().augment_manager.get_choices(player_id, GameplayRules.AUGMENT_CHOICES)
	var ids: Array[String] = []
	for definition in definitions:
		ids.append(str(definition.id))
	offers[player_id] = {"stage": active_selection_stage, "ids": ids, "pick": int(selection_pick_counts[player_id]) + 1}
	_selection_debug("stage %d offer for player %d: %s" % [active_selection_stage, player_id, ids])
	var completed_round := int(selection_context.get("round", 0))
	if player_id == 1:
		game().network_receive_offer(player_id, ids, initial, resume_player, active_selection_stage, completed_round, int(selection_pick_counts[player_id]) + 1, int(selection_pick_targets[player_id]), refresh_mode and not bool(selection_refresh_used[player_id]))
	else:
		GDSync.call_func_on(_peer_for_player(2), receive_augment_offer, player_id, ids, initial, resume_player, active_selection_stage, completed_round, int(selection_pick_counts[player_id]) + 1, int(selection_pick_targets[player_id]), refresh_mode and not bool(selection_refresh_used[player_id]))

func host_begin_round_selection(resume_player: int, completed_round: int) -> void:
	_start_selection(false, resume_player, completed_round)

func submit_augment_choice(augment_id: StringName) -> void:
	local_sequence += 1
	var stage: int = game().selection_stage_id
	_selection_debug("local submit player=%d stage=%d sequence=%d augment=%s" % [local_player_id, stage, local_sequence, augment_id])
	if is_host():
		_host_process_augment_choice(1, stage, augment_id, local_sequence)
	elif mode == Mode.CLIENT:
		GDSync.call_func_on(gdsync_host_id, request_augment_choice, stage, str(augment_id), local_sequence)

func submit_augment_refresh() -> void:
	local_sequence += 1
	var stage: int = game().selection_stage_id
	if is_host():
		_host_process_augment_refresh(1, stage)
	elif mode == Mode.CLIENT:
		GDSync.call_func_on(gdsync_host_id, request_augment_refresh, stage, local_sequence)

func submit_piece_placement(piece_id: int, position: Vector2) -> void:
	local_sequence += 1
	if is_host():
		_host_process_piece_placement(1, piece_id, position)
	elif mode == Mode.CLIENT:
		GDSync.call_func_on(gdsync_host_id, request_piece_placement, piece_id, position, local_sequence)

func submit_placement_complete() -> void:
	local_sequence += 1
	if is_host():
		_host_process_placement_complete(1)
	elif mode == Mode.CLIENT:
		GDSync.call_func_on(gdsync_host_id, request_placement_complete, local_sequence)

func submit_shot(piece_id: int, pull_vector: Vector2) -> void:
	local_sequence += 1
	if is_host():
		_host_process_shot(1, piece_id, pull_vector, local_sequence)
	elif mode == Mode.CLIENT:
		GDSync.call_func_on(gdsync_host_id, request_shot, piece_id, pull_vector, local_sequence)

func submit_active_skill(augment_id: StringName, target_ids: Array[int], board_position: Vector2 = Vector2.ZERO, targeting_option: int = 0) -> void:
	if pending_active_sequence != 0 or pending_pass_sequence != 0:
		return
	local_sequence += 1
	if is_host():
		_host_process_active(1, augment_id, target_ids, board_position, local_sequence, targeting_option)
	elif mode == Mode.CLIENT:
		pending_active_sequence = local_sequence
		pending_active_seconds = 0.0
		print("[active-skill] send id=%d player=%d host=%d type=%s position=%s" % [local_sequence, local_player_id, gdsync_host_id, augment_id, board_position])
		GDSync.call_func_on(gdsync_host_id, request_active_skill, str(augment_id), target_ids, board_position, local_sequence, targeting_option)

func _tick_active_request(delta: float) -> void:
	if pending_active_sequence == 0:
		return
	if mode != Mode.CLIENT or not match_active:
		pending_active_sequence = 0
		return
	pending_active_seconds += delta
	if pending_active_seconds >= ACTIVE_REQUEST_TIMEOUT:
		print("[active-skill] timeout id=%d host=%d" % [pending_active_sequence, gdsync_host_id])
		pending_active_sequence = 0
		game().network_active_skill_result(false, "호스트 응답 시간이 초과되었습니다. 상태를 확인한 뒤 다시 시도하세요", {})

func _process(delta: float) -> void:
	_tick_active_request(delta)
	_tick_pass_request(delta)
	if not is_host() or not match_active or game().board == null:
		return
	if game().state_machine.current in [GameStateMachine.State.INITIAL_AUGMENT_SELECTION, GameStateMachine.State.AUGMENT_SELECTION]:
		return
	snapshot_elapsed += delta
	if snapshot_elapsed >= SNAPSHOT_INTERVAL:
		snapshot_elapsed = 0.0
		var snapshot := _next_snapshot()
		_send_pending_extras()
		if snapshot.is_empty():
			return
		_record_snapshot_bytes("fast", snapshot)
		GDSync.call_func_unreliable(receive_snapshot, snapshot)

func _next_snapshot() -> Dictionary:
	pending_extras = {}
	var snapshot: Dictionary = game().create_network_snapshot()
	var extras := {
		"effects": snapshot.get("effects", {}),
		"walls": snapshot.get("walls", PackedFloat32Array()),
	}
	snapshot.erase("effects")
	snapshot.erase("walls")
	var extras_bytes := var_to_bytes(extras)
	if extras_bytes != last_slow_bytes:
		last_slow_bytes = extras_bytes
		pending_extras = extras
	var fast_bytes := var_to_bytes(snapshot)
	if fast_bytes != last_fast_bytes:
		last_fast_bytes = fast_bytes
		fast_repeats = SNAPSHOT_REPEATS
	elif fast_repeats > 0:
		fast_repeats -= 1
	else:
		heartbeat_elapsed += SNAPSHOT_INTERVAL
		if heartbeat_elapsed < SNAPSHOT_HEARTBEAT:
			return {}
	heartbeat_elapsed = 0.0
	return snapshot

func _send_pending_extras() -> void:
	if pending_extras.is_empty():
		return
	var effects: Dictionary = pending_extras["effects"]
	var walls: PackedFloat32Array = pending_extras["walls"]
	pending_extras = {}
	_record_snapshot_bytes("extras", {"effects": effects, "walls": walls})
	GDSync.call_func(receive_world_extras, effects, walls)

func _reset_snapshot_cache() -> void:
	snapshot_elapsed = 0.0
	heartbeat_elapsed = 0.0
	last_fast_bytes = PackedByteArray()
	last_slow_bytes = PackedByteArray()
	fast_repeats = 0
	pending_extras = {}
	snapshot_metrics = {
		"fast_count": 0,
		"fast_bytes": 0,
		"fast_max_bytes": 0,
		"extras_count": 0,
		"extras_bytes": 0,
		"extras_max_bytes": 0,
	}

func _record_snapshot_bytes(kind: String, payload: Dictionary) -> void:
	var byte_count := var_to_bytes(payload).size()
	var count_key := "%s_count" % kind
	var bytes_key := "%s_bytes" % kind
	var max_key := "%s_max_bytes" % kind
	snapshot_metrics[count_key] = int(snapshot_metrics.get(count_key, 0)) + 1
	snapshot_metrics[bytes_key] = int(snapshot_metrics.get(bytes_key, 0)) + byte_count
	snapshot_metrics[max_key] = maxi(int(snapshot_metrics.get(max_key, 0)), byte_count)

func get_snapshot_metrics() -> Dictionary:
	return snapshot_metrics.duplicate()

func _valid_sequence(peer_id: int, sequence: int, request_kind: String = "request") -> bool:
	var previous := int(last_sequences.get(peer_id, 0))
	if sequence <= previous:
		if OS.is_debug_build():
			push_warning("[network] rejected %s sequence from peer %d: received=%d previous=%d" % [request_kind, peer_id, sequence, previous])
		return false
	last_sequences[peer_id] = sequence
	return true

func _player_for_peer(peer_id: int) -> int:
	return int(peer_to_player.get(peer_id, 0))

func _peer_for_player(player_id: int) -> int:
	for peer_id in peer_to_player:
		if int(peer_to_player[peer_id]) == player_id:
			return int(peer_id)
	return 0

func _remote_sender_id() -> int:
	return GDSync.get_sender_id()

func request_lobby_ready(value: bool, protocol: int) -> void:
	if not is_host():
		return
	var sender := _remote_sender_id()
	if protocol != PROTOCOL_VERSION:
		GDSync.lobby_kick_client(sender, "프로토콜 버전이 일치하지 않습니다.")
		return
	var player_id := _player_for_peer(sender)
	if player_id == 2:
		ready_state[player_id] = value
		_broadcast_lobby()

func request_shot(piece_id: int, pull_vector: Vector2, sequence: int) -> void:
	if not is_host():
		return
	var sender := _remote_sender_id()
	if _valid_sequence(sender, sequence, "shot"):
		_host_process_shot(_player_for_peer(sender), piece_id, pull_vector, sequence)

func submit_pass_turn(expected_revision: int) -> void:
	if pending_pass_sequence != 0 or pending_active_sequence != 0 or not match_active:
		return
	local_sequence += 1
	if is_host():
		_host_process_pass(1, expected_revision)
	elif mode == Mode.CLIENT:
		pending_pass_sequence = local_sequence
		pending_pass_seconds = 0.0
		GDSync.call_func_on(gdsync_host_id, request_pass_turn, expected_revision, local_sequence)

func request_pass_turn(expected_revision: int, sequence: int) -> void:
	if not is_host():
		return
	var sender := _remote_sender_id()
	var player_id := _player_for_peer(sender)
	if player_id != 2:
		return
	var accepted := false
	if _valid_sequence(sender, sequence, "pass turn"):
		accepted = _host_process_pass(player_id, expected_revision)
	_send_pass_result(sender, sequence, accepted, game().create_network_snapshot())

func _host_process_pass(player_id: int, expected_revision: int) -> bool:
	if not is_host() or not match_active or player_id not in [1, 2]:
		return false
	return game().execute_pass_turn(player_id, expected_revision)

func _send_pass_result(peer_id: int, sequence: int, accepted: bool, snapshot: Dictionary) -> void:
	GDSync.call_func_on(peer_id, receive_pass_turn_result, sequence, accepted, snapshot)

func receive_pass_turn_result(sequence: int, accepted: bool, snapshot: Dictionary) -> void:
	if GDSync.get_sender_id() != gdsync_host_id:
		return
	_apply_pass_result(sequence, accepted, snapshot)

func _apply_pass_result(sequence: int, accepted: bool, snapshot: Dictionary) -> void:
	if mode != Mode.CLIENT or pending_pass_sequence == 0 or sequence != pending_pass_sequence:
		return
	pending_pass_sequence = 0
	if not snapshot.is_empty() and int(snapshot.get("turn_revision", game().turn_revision)) >= game().turn_revision:
		game().apply_network_extras(snapshot.get("effects", {}), snapshot.get("walls", PackedFloat32Array()))
		game().apply_network_snapshot(snapshot)
	game()._refresh_pass_turn_hud()
	if not accepted:
		game().update_hud("턴 넘기기가 거절되었습니다. 현재 턴 상태를 확인하세요")

func _tick_pass_request(delta: float) -> void:
	if pending_pass_sequence == 0:
		return
	pending_pass_seconds += delta
	if mode != Mode.CLIENT or not match_active or pending_pass_seconds >= ACTIVE_REQUEST_TIMEOUT:
		pending_pass_sequence = 0
		game().update_hud("턴 넘기기 응답을 받지 못했습니다. 다시 시도하세요")

func _host_process_shot(player_id: int, piece_id: int, pull_vector: Vector2, _sequence: int) -> void:
	if not is_host() or player_id == 0 or not match_active:
		return
	game().network_execute_shot(player_id, piece_id, pull_vector)

func request_augment_choice(stage: int, augment_id: String, sequence: int) -> void:
	if not is_host():
		_selection_reject("choice RPC received by non-host", 0, stage, StringName(augment_id))
		return
	var sender := _remote_sender_id()
	var player_id := _player_for_peer(sender)
	_selection_debug("remote submit peer=%d player=%d stage=%d sequence=%d augment=%s" % [sender, player_id, stage, sequence, augment_id])
	if not _valid_sequence(sender, sequence, "augment choice"):
		_selection_reject("duplicate or stale sequence", player_id, stage, StringName(augment_id))
		return
	_host_process_augment_choice(player_id, stage, StringName(augment_id), sequence)

func request_augment_refresh(stage: int, sequence: int) -> void:
	if not is_host():
		return
	var sender := _remote_sender_id()
	if _valid_sequence(sender, sequence, "augment refresh"):
		_host_process_augment_refresh(_player_for_peer(sender), stage)

func _host_process_augment_refresh(player_id: int, stage: int) -> void:
	if not is_host() or not match_active or not refresh_mode:
		return
	if player_id not in [1, 2] or stage != active_selection_stage or bool(selection_completed.get(player_id, false)):
		return
	if bool(selection_refresh_used.get(player_id, false)) or not offers.has(player_id):
		return
	selection_refresh_used[player_id] = true
	var previous_ids: Array = (offers[player_id] as Dictionary).get("ids", [])
	var initial := bool(selection_context.get("initial", false))
	var resume := int(selection_context.get("resume", 1))
	# Retry a few times to avoid presenting the exact same set when the pool allows it.
	var ids: Array[String] = []
	for attempt in 4:
		ids.clear()
		for definition in game().augment_manager.get_choices(player_id, GameplayRules.AUGMENT_CHOICES):
			ids.append(str(definition.id))
		if ids != previous_ids or attempt == 3:
			break
	offers[player_id] = {"stage": active_selection_stage, "ids": ids, "pick": int(selection_pick_counts[player_id]) + 1}
	var completed_round := int(selection_context.get("round", 0))
	if player_id == 1:
		game().network_receive_offer(player_id, ids, initial, resume, active_selection_stage, completed_round, int(selection_pick_counts[player_id]) + 1, int(selection_pick_targets[player_id]), false)
	else:
		GDSync.call_func_on(_peer_for_player(2), receive_augment_offer, player_id, ids, initial, resume, active_selection_stage, completed_round, int(selection_pick_counts[player_id]) + 1, int(selection_pick_targets[player_id]), false)

func request_piece_placement(piece_id: int, position: Vector2, sequence: int) -> void:
	if not is_host():
		return
	var sender := _remote_sender_id()
	if _valid_sequence(sender, sequence, "piece placement"):
		_host_process_piece_placement(_player_for_peer(sender), piece_id, position)

func _host_process_piece_placement(player_id: int, piece_id: int, position: Vector2) -> void:
	if not is_host() or not match_active or bool(placement_completed.get(player_id, false)):
		return
	if not game().network_validate_and_place_piece(player_id, piece_id, position):
		return
	_broadcast_placement_state(piece_id, position)

func request_placement_complete(sequence: int) -> void:
	if not is_host():
		return
	var sender := _remote_sender_id()
	if _valid_sequence(sender, sequence, "placement complete"):
		_host_process_placement_complete(_player_for_peer(sender))

func _host_process_placement_complete(player_id: int) -> void:
	if not is_host() or not match_active or player_id not in [1, 2]:
		return
	if bool(placement_completed.get(player_id, false)) or not game().validate_player_placement(player_id):
		return
	placement_completed[player_id] = true
	_broadcast_placement_state(-1, Vector2.ZERO)
	if bool(placement_completed[1]) and bool(placement_completed[2]):
		_start_selection(true, 1, 0)

func _broadcast_placement_state(piece_id: int, position: Vector2) -> void:
	var completed := placement_completed.duplicate()
	GDSync.call_func(receive_placement_state, piece_id, position, completed)
	game().network_receive_placement_state(piece_id, position, completed)

func _host_process_augment_choice(player_id: int, stage: int, augment_id: StringName, _sequence: int) -> void:
	if not is_host():
		_selection_reject("processor is not host", player_id, stage, augment_id)
		return
	if not match_active:
		_selection_reject("match is not active", player_id, stage, augment_id)
		return
	if player_id not in [1, 2]:
		_selection_reject("unknown network player", player_id, stage, augment_id)
		return
	if stage != active_selection_stage:
		_selection_reject("stage mismatch", player_id, stage, augment_id)
		return
	if bool(selection_completed.get(player_id, false)):
		_selection_reject("player already selected", player_id, stage, augment_id)
		return
	if not offers.has(player_id):
		_selection_reject("no offer for player", player_id, stage, augment_id)
		return
	if not game().augment_manager.can_acquire(player_id):
		_selection_reject("augment inventory is full", player_id, stage, augment_id)
		return
	var offer: Dictionary = offers[player_id]
	if int(offer.get("stage", -1)) != stage:
		_selection_reject("offer stage mismatch", player_id, stage, augment_id)
		return
	if not str(augment_id) in offer.get("ids", []):
		_selection_reject("augment was not offered", player_id, stage, augment_id)
		return
	# Commit each pick once. Acquiring immediately makes the next offer naturally
	# exclude the previous augment and keeps duplicate requests idempotent.
	offers.erase(player_id)
	if not game().augment_manager.acquire(game(), player_id, augment_id):
		_selection_reject("augment_manager.acquire failed", player_id, stage, augment_id)
		return
	selection_pick_counts[player_id] = int(selection_pick_counts[player_id]) + 1
	GDSync.call_func(receive_augment_granted, player_id, str(augment_id))
	game().network_augment_granted(player_id, augment_id)
	selection_completed[player_id] = int(selection_pick_counts[player_id]) >= int(selection_pick_targets[player_id]) or not game().augment_manager.can_acquire(player_id)
	_selection_debug("stage %d accepted player %d augment=%s picks=%d/%d" % [stage, player_id, augment_id, selection_pick_counts[player_id], selection_pick_targets[player_id]])
	if not bool(selection_completed[player_id]):
		_begin_selection(player_id, bool(selection_context.get("initial", false)), int(selection_context.get("resume", 1)))
		return
	if not (bool(selection_completed[1]) and bool(selection_completed[2])):
		if player_id == 1:
			game().network_show_waiting("상대 플레이어의 증강 선택을 기다리는 중…")
		return
	var initial := bool(selection_context.get("initial", false))
	var resume := int(selection_context.get("resume", 1))
	var completed_round := int(selection_context.get("round", 0))
	offers.clear()
	pending_choices.clear()
	_selection_debug("stage %d committed for both players (initial=%s)" % [stage, initial])
	GDSync.call_func(receive_selection_complete, stage, resume, completed_round, initial)
	game().network_selection_complete(stage, resume, completed_round, initial)

func request_active_skill(augment_id: String, target_ids: Array, board_position: Vector2, sequence: int, targeting_option: int = 0) -> void:
	if not is_host():
		return
	var sender := _remote_sender_id()
	var player_id := _player_for_peer(sender)
	if player_id != 2:
		return # Unknown senders cannot mutate the match.
	var key := "%d:%d" % [sender, sequence]
	print("[active-skill] receive id=%d sender=%d host=%d type=%s position=%s state=%s" % [sequence, sender, gdsync_host_id, augment_id, board_position, game().state_machine.current])
	if active_results.has(key):
		_send_active_result(sender, sequence, active_results[key])
		return
	active_response_context = true
	active_response_reason = ""
	var accepted := false
	var validated_target_ids: Array[int] = []
	if not _valid_sequence(sender, sequence, "active skill"):
		active_response_reason = "중복되거나 오래된 요청입니다"
	elif not validate_active_target_ids(target_ids, validated_target_ids):
		active_response_reason = "대상 ID 형식이 올바르지 않습니다"
	else:
		accepted = _host_process_active(player_id, StringName(augment_id), validated_target_ids, board_position, sequence, targeting_option)
	active_response_context = false
	var result := {"accepted": accepted, "reason": active_response_reason, "snapshot": game().create_network_snapshot()}
	active_results[key] = result
	if active_results.size() > 64:
		active_results.erase(active_results.keys()[0])
	_send_active_result(sender, sequence, result)

func _send_active_result(peer_id: int, sequence: int, result: Dictionary) -> void:
	print("[active-skill] response id=%d peer=%d accepted=%s reason=%s state=%s" % [sequence, peer_id, result.accepted, result.reason, result.snapshot.get("state")])
	GDSync.call_func_on(peer_id, receive_active_skill_result, sequence, result.accepted, result.reason, result.snapshot)

func receive_active_skill_result(sequence: int, accepted: bool, reason: String, snapshot: Dictionary) -> void:
	if GDSync.get_sender_id() != gdsync_host_id:
		return
	_apply_active_result(sequence, accepted, reason, snapshot)

func _apply_active_result(sequence: int, accepted: bool, reason: String, snapshot: Dictionary) -> void:
	if sequence != pending_active_sequence or pending_active_sequence == 0:
		return
	print("[active-skill] result received id=%d host=%d accepted=%s state=%s" % [sequence, gdsync_host_id, accepted, snapshot.get("state")])
	pending_active_sequence = 0
	game().network_active_skill_result(accepted, reason, snapshot)

func validate_active_target_ids(raw_target_ids: Array, validated_target_ids: Array[int]) -> bool:
	validated_target_ids.clear()
	for target_id in raw_target_ids:
		if typeof(target_id) != TYPE_INT:
			if OS.is_debug_build():
				push_warning("[network] rejected active skill with non-integer target id: %s" % target_id)
			return false
		validated_target_ids.append(int(target_id))
	return true

func _host_process_active(player_id: int, augment_id: StringName, target_ids: Array[int], board_position: Vector2, _sequence: int, targeting_option: int = 0) -> bool:
	if OS.is_debug_build():
		print("[active-skill] host request: id=%d player=%d augment=%s targets=%s position=%s current_player=%d state=%s" % [_sequence, player_id, augment_id, target_ids, board_position, game().current_player, GameStateMachine.State.keys()[game().state_machine.current]])
	if not is_host():
		return false
	if player_id not in [1, 2] or player_id != game().current_player:
		_reject_active_skill(player_id, "현재 플레이어의 차례가 아닙니다")
		return false
	if not game().state_machine.allows_aiming():
		_reject_active_skill(player_id, "현재 상태에서는 스킬을 사용할 수 없습니다")
		return false
	var effect: AugmentEffect
	for candidate: AugmentEffect in game().augment_manager.effects[player_id]:
		if candidate.definition.id == augment_id:
			effect = candidate
			break
	if effect == null:
		_reject_active_skill(player_id, "보유하지 않은 스킬입니다")
		return false
	if not effect.can_activate(game(), player_id):
		_reject_active_skill(player_id, "사용 횟수 또는 재사용 대기시간 조건을 만족하지 않습니다")
		return false
	if augment_id == &"wall_maria":
		if targeting_option not in [0, 1]:
			_reject_active_skill(player_id, "벽 방향 값이 올바르지 않습니다")
			return false
		effect.apply_targeting_option(targeting_option)
	var required := 0
	if effect.definition.target_mode in [AugmentDefinition.TargetMode.OWN_PIECE, AugmentDefinition.TargetMode.ENEMY_PIECE]:
		required = 1
	if effect.definition.target_mode == AugmentDefinition.TargetMode.TWO_OWN_PIECES or augment_id == &"wizard":
		required = 2
	if target_ids.size() != required or (target_ids.size() == 2 and target_ids[0] == target_ids[1]):
		_reject_active_skill(player_id, "필요한 대상 수가 올바르지 않습니다")
		return false
	for index in target_ids.size():
		var validated_piece: AlkkagiPiece = game().find_piece(target_ids[index])
		if validated_piece == null:
			_reject_active_skill(player_id, "대상 바둑알을 찾을 수 없습니다")
			return false
		if augment_id == &"wizard":
			if (index == 0 and validated_piece.owner_id != player_id) or (index == 1 and validated_piece.owner_id == player_id):
				_reject_active_skill(player_id, "마법사 대상 순서가 올바르지 않습니다")
				return false
		elif effect.definition.target_mode in [AugmentDefinition.TargetMode.OWN_PIECE, AugmentDefinition.TargetMode.TWO_OWN_PIECES] and validated_piece.owner_id != player_id:
			_reject_active_skill(player_id, "자신의 바둑알을 선택해야 합니다")
			return false
		elif effect.definition.target_mode == AugmentDefinition.TargetMode.ENEMY_PIECE and validated_piece.owner_id == player_id:
			_reject_active_skill(player_id, "상대 바둑알을 선택해야 합니다")
			return false
	if effect.definition.target_mode == AugmentDefinition.TargetMode.NONE:
		effect.activate_immediate(game(), player_id)
	elif effect.definition.target_mode == AugmentDefinition.TargetMode.BOARD_POSITION:
		if not effect.on_position_target(game(), player_id, board_position):
			_reject_active_skill(player_id, "해당 위치에는 설치할 수 없습니다")
			return false
	else:
		var applied := false
		for index in target_ids.size():
			var target_id: int = target_ids[index]
			var piece: AlkkagiPiece = game().find_piece(target_id)
			if piece == null:
				_reject_active_skill(player_id, "대상 바둑알이 사라졌습니다")
				return false
			var accepted := effect.on_piece_target(game(), player_id, piece)
			if index == target_ids.size() - 1:
				applied = accepted
		if not applied:
			effect.cancel_active()
			_reject_active_skill(player_id, "선택한 대상에 스킬을 적용할 수 없습니다")
			return false

	return true

func _reject_active_skill(player_id: int, reason: String) -> void:
	if active_response_context:
		active_response_reason = reason
		return
	if OS.is_debug_build():
		push_warning("[active-skill] rejected player %d: %s" % [player_id, reason])
	if player_id == 1:
		game().network_active_skill_rejected(reason)
	elif player_id == 2:
		var peer_id := _peer_for_player(2)
		if peer_id != 0:
			GDSync.call_func_on(peer_id, receive_active_skill_rejected, reason)

func broadcast_piece_sound(kind: String, volume_db: float) -> void:
	if not is_host():
		return
	GDSync.call_func(receive_piece_sound, kind, volume_db)

func receive_piece_sound(kind: String, volume_db: float) -> void:
	if GDSync.get_sender_id() != gdsync_host_id:
		return
	if mode == Mode.CLIENT and match_active:
		game().play_piece_sound(kind, volume_db)

func broadcast_projectile(from: Vector2, to: Vector2, color: Color, size: float) -> void:
	if is_host():
		GDSync.call_func(receive_projectile, from, to, color, size)

func receive_projectile(from: Vector2, to: Vector2, color: Color, size: float) -> void:
	if mode == Mode.CLIENT:
		game().animate_projectile(from, to, color, size, false)

func receive_lobby(data: Dictionary) -> void:
	if GDSync.get_sender_id() != gdsync_host_id:
		return
	piece_count = int(data.get("piece_count", GameplayRules.DEFAULT_PIECES))
	ready_state = data.get("ready", {1: false, 2: false})
	connected_players = data.get("connected", {1: true, 2: true})
	refresh_mode = bool(data.get("refresh_mode", false))
	chaos_mode = bool(data.get("chaos_mode", false))
	lobby_updated.emit(data)

func receive_augment_offer(player_id: int, ids: Array[String], initial: bool, resume_player: int, stage: int, completed_round: int, pick_index: int = 1, pick_total: int = 1, refresh_available: bool = false) -> void:
	game().network_receive_offer(player_id, ids, initial, resume_player, stage, completed_round, pick_index, pick_total, refresh_available)

func receive_augment_granted(player_id: int, augment_id: String) -> void:
	if not game().augment_manager.has_augment(player_id, StringName(augment_id)):
		game().augment_manager.acquire(game(), player_id, StringName(augment_id))
	game().network_augment_granted(player_id, StringName(augment_id))

func receive_world_start(count: int, refresh_enabled: bool = false, chaos_enabled: bool = false) -> void:
	match_active = true
	last_snapshot_received_usec = 0
	_reset_snapshot_cache()
	refresh_mode = refresh_enabled
	chaos_mode = chaos_enabled
	game().network_prepare_match(false, local_player_id, count, refresh_mode, chaos_mode)
	game().network_start_world(count)

func receive_selection_complete(stage: int, resume_player: int, completed_round: int, initial: bool = false) -> void:
	game().network_selection_complete(stage, resume_player, completed_round, initial)

func receive_placement_state(piece_id: int, position: Vector2, completed: Dictionary) -> void:
	placement_completed = completed
	game().network_receive_placement_state(piece_id, position, completed)

func receive_active_skill_rejected(reason: String) -> void:
	game().network_active_skill_rejected(reason)

func receive_world_extras(effects: Dictionary, walls: PackedFloat32Array) -> void:
	if GDSync.get_sender_id() != gdsync_host_id:
		return
	if mode == Mode.CLIENT and match_active:
		game().apply_network_extras(effects, walls)

func receive_snapshot(snapshot: Dictionary) -> void:
	if mode == Mode.CLIENT:
		var now_usec := Time.get_ticks_usec()
		var interpolation_duration := SNAPSHOT_INTERVAL
		if last_snapshot_received_usec > 0:
			var gap := float(now_usec - last_snapshot_received_usec) / 1000000.0
			interpolation_duration = SNAPSHOT_INTERVAL if gap > SNAPSHOT_IDLE_GAP else clampf(gap, SNAPSHOT_INTERVAL * 0.5, 0.15)
		last_snapshot_received_usec = now_usec
		game().apply_network_snapshot(snapshot, interpolation_duration)

func _lobby_data() -> Dictionary:
	return {
		"piece_count": piece_count,
		"ready": ready_state.duplicate(),
		"connected": connected_players.duplicate(),
		"refresh_mode": refresh_mode,
		"chaos_mode": chaos_mode,
		"host": 1,
	}

func _emit_lobby() -> void:
	lobby_updated.emit(_lobby_data())

func _broadcast_lobby() -> void:
	var data := _lobby_data()
	GDSync.call_func(receive_lobby, data)
	lobby_updated.emit(data)

func _on_gdsync_lobby_created(lobby_name: String) -> void:
	if mode != Mode.HOST or lobby_name != ROOM_PREFIX + room_code:
		return
	GDSync.lobby_join(lobby_name)

func _on_gdsync_lobby_creation_failed(lobby_name: String, error: int) -> void:
	if mode != Mode.HOST or lobby_name != ROOM_PREFIX + room_code:
		return
	if error == ENUMS.LOBBY_CREATION_ERROR.LOBBY_ALREADY_EXISTS and room_create_attempts < ROOM_CREATE_ATTEMPTS:
		connection_message.emit("방 코드 충돌. 새 코드를 발급합니다…", false)
		await get_tree().create_timer(3.1).timeout
		if mode == Mode.HOST:
			_create_online_room_attempt()
		return
	var reason: String = str(ENUMS.LOBBY_CREATION_ERROR.keys()[error]) if error >= 0 and error < ENUMS.LOBBY_CREATION_ERROR.size() else "UNKNOWN"
	shutdown(false)
	connection_message.emit("온라인 방 생성 실패: %s (error=%d)" % [reason, error], true)

func _on_gdsync_lobby_joined(lobby_name: String) -> void:
	if OS.is_debug_build():
		print("[gdsync] lobby_joined name=%s expected=%s mode=%s host=%d self=%d" % [lobby_name, ROOM_PREFIX + room_code, Mode.keys()[mode], GDSync.get_host(), GDSync.get_client_id()])
	if not is_online() or lobby_name != ROOM_PREFIX + room_code:
		return
	var lobby_protocol := int(GDSync.lobby_get_tag("protocol", -1))
	if lobby_protocol != PROTOCOL_VERSION:
		var expected_code := room_code
		shutdown(false)
		connection_message.emit("온라인 방 %s의 프로토콜 버전이 일치하지 않습니다. (방 %d / 현재 %d)" % [expected_code, lobby_protocol, PROTOCOL_VERSION], true)
		return
	var own_id := GDSync.get_client_id()
	if mode == Mode.HOST:
		gdsync_host_id = own_id
		mode = Mode.HOST
		local_player_id = 1
		peer_to_player = {own_id: 1}
		connected_players = {1: true, 2: false}
		connection_message.emit("온라인 방 생성 완료 · 코드 %s" % room_code, false)
	else:
		gdsync_host_id = GDSync.get_host()
		mode = Mode.CLIENT
		local_player_id = 2
		peer_to_player = {gdsync_host_id: 1, own_id: 2}
		connected_players = {1: true, 2: true}
		connection_message.emit("온라인 방 %s에 참가했습니다." % room_code, false)
	_emit_lobby()

func _on_gdsync_lobby_join_failed(lobby_name: String, error: int) -> void:
	if OS.is_debug_build():
		print("[gdsync] lobby_join_failed name=%s error=%d mode=%s" % [lobby_name, error, Mode.keys()[mode]])
	if mode != Mode.CLIENT or lobby_name != ROOM_PREFIX + room_code:
		return
	var reason: String = str(ENUMS.LOBBY_JOIN_ERROR.keys()[error]) if error >= 0 and error < ENUMS.LOBBY_JOIN_ERROR.size() else "UNKNOWN"
	shutdown(false)
	connection_message.emit("온라인 방 참가 실패: %s (error=%d)" % [reason, error], true)

func _on_gdsync_client_joined(client_id: int) -> void:
	if not is_online() or client_id == GDSync.get_client_id():
		return
	if mode == Mode.HOST:
		if bool(connected_players[2]):
			GDSync.lobby_kick_client(client_id, "이 방은 2인 전용입니다.")
			return
		peer_to_player[client_id] = 2
		connected_players[2] = true
		ready_state[2] = false
		connection_message.emit("친구가 온라인 방에 참가했습니다.", false)
		_broadcast_lobby()

func _on_gdsync_client_left(client_id: int) -> void:
	if not is_online() or shutting_down:
		return
	var player_id := _player_for_peer(client_id)
	peer_to_player.erase(client_id)
	if mode == Mode.HOST and player_id == 2:
		connected_players[2] = false
		ready_state[2] = false
		match_active = false
		_reset_selection_state()
		_reset_snapshot_cache()
		session_ended.emit("참가자의 연결이 끊겼습니다.")
		_broadcast_lobby()
	elif mode == Mode.CLIENT and client_id == gdsync_host_id:
		shutdown(false)
		session_ended.emit("방장이 방을 나갔거나 연결이 끊겼습니다.")

func _on_gdsync_host_changed(_is_host: bool, new_host_id: int) -> void:
	if OS.is_debug_build():
		print("[gdsync] host_changed new=%d tracked=%d mode=%s" % [new_host_id, gdsync_host_id, Mode.keys()[mode]])
	if mode == Mode.CLIENT:
		if gdsync_host_id < 0:
			gdsync_host_id = new_host_id
			peer_to_player.erase(-1)
			peer_to_player[new_host_id] = 1
			connected_players[1] = true
			_emit_lobby()
		elif new_host_id != gdsync_host_id:
			shutdown(false)
			session_ended.emit("방장 연결이 끊겨 온라인 대전을 종료합니다.")

func _on_gdsync_disconnected() -> void:
	gdsync_connected = false
	if is_online() and not shutting_down:
		shutdown(false)
		session_ended.emit("GD-Sync 서버와 연결이 끊겼습니다.")

func _on_gdsync_connected() -> void:
	gdsync_connected = true
