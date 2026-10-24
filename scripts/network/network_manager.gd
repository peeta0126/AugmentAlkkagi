class_name AlkkagiNetworkManager
extends Node

signal lobby_updated(data: Dictionary)
signal connection_message(text: String, is_error: bool)
signal session_ended(reason: String)

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 1
const SNAPSHOT_INTERVAL := 0.05
const PROTOCOL_VERSION := 2
const ROOM_PREFIX := "AA-"
const ROOM_CODE_LENGTH := 6
const ROOM_CREATE_ATTEMPTS := 5

enum Mode { OFFLINE, HOST, CLIENT, GDSYNC_HOST, GDSYNC_CLIENT }

var mode := Mode.OFFLINE
var local_player_id := 0
var peer_to_player: Dictionary = {1: 1}
var ready_state: Dictionary = {1: false, 2: false}
var connected_players: Dictionary = {1: true, 2: false}
var piece_count := GameplayRules.DEFAULT_PIECES
var match_active := false
var offers: Dictionary = {}
var selection_context: Dictionary = {}
var active_selection_stage := 0
var selection_completed: Dictionary = {1: false, 2: false}
var pending_choices: Dictionary = {}
var last_sequences: Dictionary = {}
var local_sequence := 0
var snapshot_elapsed := 0.0
var shutting_down := false
var room_code := ""
var room_create_attempts := 0
var gdsync_host_id := -1
var gdsync_connected := false

func _ready() -> void:
	name = "NetworkManager"
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
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
	GDSync.expose_func(receive_lobby, ENUMS.EXPOSE_PERMISSION.HOST)

func game() -> Node:
	return get_parent()

func _selection_debug(message: String) -> void:
	if OS.is_debug_build():
		print("[augment-selection] %s" % message)

func _selection_reject(reason: String, player_id: int, stage: int, augment_id: StringName = &"") -> void:
	if OS.is_debug_build():
		push_warning("[augment-selection] rejected: %s (player=%d stage=%d active_stage=%d augment=%s completed=%s pending=%s)" % [reason, player_id, stage, active_selection_stage, augment_id, selection_completed, pending_choices])

func create_host(port: int = DEFAULT_PORT) -> Error:
	shutdown(false)
	last_sequences.clear()
	local_sequence = 0
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		connection_message.emit("UDP %d 포트를 열 수 없습니다: %s" % [port, error_string(error)], true)
		return error
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	local_player_id = 1
	peer_to_player = {1: 1}
	ready_state = {1: false, 2: false}
	connected_players = {1: true, 2: false}
	connection_message.emit("호스트가 UDP %d에서 대기 중입니다." % port, false)
	_emit_lobby()
	return OK

func join_host(address: String, port: int = DEFAULT_PORT) -> Error:
	shutdown(false)
	last_sequences.clear()
	local_sequence = 0
	if not address.is_valid_ip_address() or ":" in address or port < 1 or port > 65535:
		connection_message.emit("올바른 IPv4 주소를 입력하세요.", true)
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		connection_message.emit("접속을 시작할 수 없습니다: %s" % error_string(error), true)
		return error
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	local_player_id = 2
	connection_message.emit("%s:%d에 연결 중…" % [address, port], false)
	return OK

func create_online_room(preferred_code: String = "") -> Error:
	if not gdsync_connected:
		connection_message.emit("GD-Sync 서버에 아직 연결되지 않았습니다.", true)
		return ERR_UNAVAILABLE
	shutdown(false)
	mode = Mode.GDSYNC_HOST
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
	mode = Mode.GDSYNC_CLIENT
	local_player_id = 2
	room_code = normalized
	_reset_lobby_state()
	connected_players[1] = false
	connection_message.emit("온라인 방 %s 참가 중…" % room_code, false)
	GDSync.lobby_join(ROOM_PREFIX + room_code)
	return OK

func _reset_lobby_state() -> void:
	last_sequences.clear()
	local_sequence = 0
	peer_to_player.clear()
	ready_state = {1: false, 2: false}
	connected_players = {1: true, 2: false}
	match_active = false
	gdsync_host_id = -1

func shutdown(notify: bool = true) -> void:
	if mode == Mode.OFFLINE:
		return
	shutting_down = true
	if is_gdsync_mode() and not GDSync.lobby_get_name().is_empty():
		GDSync.lobby_leave()
	elif multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.OFFLINE
	local_player_id = 0
	match_active = false
	offers.clear()
	selection_context.clear()
	pending_choices.clear()
	selection_completed = {1: false, 2: false}
	room_code = ""
	gdsync_host_id = -1
	shutting_down = false
	if notify:
		session_ended.emit("네트워크 방에서 나왔습니다.")

func is_online() -> bool:
	return mode != Mode.OFFLINE

func is_host() -> bool:
	return mode in [Mode.HOST, Mode.GDSYNC_HOST]

func is_gdsync_mode() -> bool:
	return mode in [Mode.GDSYNC_HOST, Mode.GDSYNC_CLIENT]

func get_room_code() -> String:
	return room_code

func set_ready(value: bool) -> void:
	if is_host():
		ready_state[1] = value
		_broadcast_lobby()
	elif mode == Mode.CLIENT:
		request_lobby_ready.rpc_id(1, value, PROTOCOL_VERSION)
	elif mode == Mode.GDSYNC_CLIENT and gdsync_host_id >= 0:
		GDSync.call_func_on(gdsync_host_id, request_lobby_ready, value, PROTOCOL_VERSION)

func set_piece_count(value: int) -> void:
	if not is_host() or match_active:
		return
	piece_count = GameplayRules.clamp_piece_count(value)
	_broadcast_lobby()

func can_start() -> bool:
	return is_host() and bool(connected_players[1]) and bool(connected_players[2]) and bool(ready_state[1]) and bool(ready_state[2])

func start_match() -> bool:
	if not can_start():
		connection_message.emit("두 플레이어가 접속하고 모두 준비해야 합니다.", true)
		return false
	match_active = true
	game().network_prepare_match(true, 1, piece_count)
	_start_selection(true, 1, 0)
	return true

func return_to_lobby() -> void:
	if mode != Mode.HOST:
		return
	match_active = false
	ready_state = {1: false, 2: false}
	receive_return_lobby.rpc()
	game()._show_network_lobby()
	_broadcast_lobby()

@rpc("authority", "call_remote", "reliable")
func receive_return_lobby() -> void:
	match_active = false
	game()._show_network_lobby()

func _start_selection(initial: bool, resume_player: int, completed_round: int) -> void:
	if mode != Mode.HOST:
		_selection_reject("selection start requested by non-host", local_player_id, active_selection_stage)
		return
	active_selection_stage += 1
	offers.clear()
	pending_choices.clear()
	selection_completed = {1: false, 2: false}
	selection_context = {"initial": initial, "resume": resume_player, "round": completed_round}
	_selection_debug("stage %d started (initial=%s round=%d resume=%d)" % [active_selection_stage, initial, completed_round, resume_player])
	_begin_selection(2, initial, resume_player)
	_begin_selection(1, initial, resume_player)

func _begin_selection(player_id: int, initial: bool, resume_player: int) -> void:
	if mode != Mode.HOST:
		_selection_reject("offer generation requested by non-host", player_id, active_selection_stage)
		return
	var definitions: Array[AugmentDefinition] = game().augment_manager.get_choices(player_id, 3)
	var ids: Array[String] = []
	for definition in definitions:
		ids.append(str(definition.id))
	offers[player_id] = {"stage": active_selection_stage, "ids": ids}
	_selection_debug("stage %d offer for player %d: %s" % [active_selection_stage, player_id, ids])
	var completed_round := int(selection_context.get("round", 0))
	if player_id == 1:
		game().network_receive_offer(player_id, ids, initial, resume_player, active_selection_stage, completed_round)
	else:
		receive_augment_offer.rpc_id(_peer_for_player(2), player_id, ids, initial, resume_player, active_selection_stage, completed_round)
		game().network_show_waiting("백돌 플레이어가 증강을 선택하는 중…")

func host_begin_round_selection(resume_player: int, completed_round: int) -> void:
	_start_selection(false, resume_player, completed_round)

func submit_augment_choice(augment_id: StringName) -> void:
	local_sequence += 1
	var stage: int = game().selection_stage_id
	_selection_debug("local submit player=%d stage=%d sequence=%d augment=%s" % [local_player_id, stage, local_sequence, augment_id])
	if mode == Mode.HOST:
		_host_process_augment_choice(1, stage, augment_id, local_sequence)
	elif mode == Mode.CLIENT:
		request_augment_choice.rpc_id(1, stage, str(augment_id), local_sequence)

func submit_shot(piece_id: int, pull_vector: Vector2) -> void:
	local_sequence += 1
	if mode == Mode.HOST:
		_host_process_shot(1, piece_id, pull_vector, local_sequence)
	elif mode == Mode.CLIENT:
		request_shot.rpc_id(1, piece_id, pull_vector, local_sequence)

func submit_active_skill(augment_id: StringName, target_ids: Array[int], board_position: Vector2 = Vector2.ZERO) -> void:
	local_sequence += 1
	if mode == Mode.HOST:
		_host_process_active(1, augment_id, target_ids, board_position, local_sequence)
	elif mode == Mode.CLIENT:
		request_active_skill.rpc_id(1, str(augment_id), target_ids, board_position, local_sequence)

func _process(delta: float) -> void:
	if mode != Mode.HOST or not match_active or game().board == null:
		return
	if game().state_machine.current in [GameStateMachine.State.INITIAL_AUGMENT_SELECTION, GameStateMachine.State.AUGMENT_SELECTION]:
		return
	snapshot_elapsed += delta
	if snapshot_elapsed >= SNAPSHOT_INTERVAL:
		snapshot_elapsed = 0.0
		receive_snapshot.rpc(game().create_network_snapshot())

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

@rpc("any_peer", "call_remote", "reliable")
func request_lobby_ready(value: bool, protocol: int) -> void:
	if not is_host():
		return
	var sender := GDSync.get_sender_id() if is_gdsync_mode() else multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL_VERSION:
		if is_gdsync_mode():
			GDSync.lobby_kick_client(sender, "프로토콜 버전이 일치하지 않습니다.")
		else:
			multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	var player_id := _player_for_peer(sender)
	if player_id == 2:
		ready_state[player_id] = value
		_broadcast_lobby()

@rpc("any_peer", "call_remote", "reliable")
func request_shot(piece_id: int, pull_vector: Vector2, sequence: int) -> void:
	if mode != Mode.HOST:
		return
	var sender := multiplayer.get_remote_sender_id()
	if _valid_sequence(sender, sequence, "shot"):
		_host_process_shot(_player_for_peer(sender), piece_id, pull_vector, sequence)

func _host_process_shot(player_id: int, piece_id: int, pull_vector: Vector2, _sequence: int) -> void:
	if mode != Mode.HOST or player_id == 0 or not match_active:
		return
	game().network_execute_shot(player_id, piece_id, pull_vector)

@rpc("any_peer", "call_remote", "reliable")
func request_augment_choice(stage: int, augment_id: String, sequence: int) -> void:
	if mode != Mode.HOST:
		_selection_reject("choice RPC received by non-host", 0, stage, StringName(augment_id))
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_id := _player_for_peer(sender)
	_selection_debug("remote submit peer=%d player=%d stage=%d sequence=%d augment=%s" % [sender, player_id, stage, sequence, augment_id])
	if not _valid_sequence(sender, sequence, "augment choice"):
		_selection_reject("duplicate or stale sequence", player_id, stage, StringName(augment_id))
		return
	_host_process_augment_choice(player_id, stage, StringName(augment_id), sequence)

func _host_process_augment_choice(player_id: int, stage: int, augment_id: StringName, _sequence: int) -> void:
	if mode != Mode.HOST:
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
	pending_choices[player_id] = augment_id
	selection_completed[player_id] = true
	_selection_debug("stage %d accepted player %d augment=%s completed=%s" % [stage, player_id, augment_id, selection_completed])
	if not (bool(selection_completed[1]) and bool(selection_completed[2])):
		return
	for selected_player in [1, 2]:
		var selected_id: StringName = pending_choices.get(selected_player, StringName())
		if selected_id == StringName():
			_selection_reject("completed player has no pending choice", selected_player, stage)
			return
		if not game().augment_manager.can_acquire(selected_player):
			_selection_reject("inventory became full before commit", selected_player, stage, selected_id)
			return
	for selected_player in [1, 2]:
		var selected_id: StringName = pending_choices[selected_player]
		if not game().augment_manager.acquire(game(), selected_player, selected_id):
			_selection_reject("augment_manager.acquire failed", selected_player, stage, selected_id)
			return
		receive_augment_granted.rpc(selected_player, str(selected_id))
		game().network_augment_granted(selected_player, selected_id)
	var initial := bool(selection_context.get("initial", false))
	var resume := int(selection_context.get("resume", 1))
	var completed_round := int(selection_context.get("round", 0))
	offers.clear()
	pending_choices.clear()
	_selection_debug("stage %d committed for both players (initial=%s)" % [stage, initial])
	if initial:
		receive_world_start.rpc(piece_count)
		game().network_start_world(piece_count)
	else:
		receive_selection_complete.rpc(stage, resume, completed_round)
		game().network_selection_complete(stage, resume, completed_round)

@rpc("any_peer", "call_remote", "reliable")
func request_active_skill(augment_id: String, target_ids: Array, board_position: Vector2, sequence: int) -> void:
	if mode != Mode.HOST:
		return
	var sender := multiplayer.get_remote_sender_id()
	var player_id := _player_for_peer(sender)
	if not _valid_sequence(sender, sequence, "active skill"):
		_reject_active_skill(player_id, "중복되거나 오래된 요청입니다")
		return
	var validated_target_ids: Array[int] = []
	if not validate_active_target_ids(target_ids, validated_target_ids):
		_reject_active_skill(player_id, "대상 ID 형식이 올바르지 않습니다")
		return
	_host_process_active(player_id, StringName(augment_id), validated_target_ids, board_position, sequence)

func validate_active_target_ids(raw_target_ids: Array, validated_target_ids: Array[int]) -> bool:
	validated_target_ids.clear()
	for target_id in raw_target_ids:
		if typeof(target_id) != TYPE_INT:
			if OS.is_debug_build():
				push_warning("[network] rejected active skill with non-integer target id: %s" % target_id)
			return false
		validated_target_ids.append(int(target_id))
	return true

func _host_process_active(player_id: int, augment_id: StringName, target_ids: Array[int], board_position: Vector2, _sequence: int) -> void:
	if OS.is_debug_build():
		print("[active-skill] host request: player=%d augment=%s targets=%s position=%s current_player=%d state=%s" % [player_id, augment_id, target_ids, board_position, game().current_player, GameStateMachine.State.keys()[game().state_machine.current]])
	if mode != Mode.HOST:
		return
	if player_id != game().current_player:
		_reject_active_skill(player_id, "현재 플레이어의 차례가 아닙니다")
		return
	if not game().state_machine.allows_aiming():
		_reject_active_skill(player_id, "현재 상태에서는 스킬을 사용할 수 없습니다")
		return
	var effect: AugmentEffect
	for candidate: AugmentEffect in game().augment_manager.effects[player_id]:
		if candidate.definition.id == augment_id:
			effect = candidate
			break
	if effect == null:
		_reject_active_skill(player_id, "보유하지 않은 스킬입니다")
		return
	if not effect.can_activate(game(), player_id):
		_reject_active_skill(player_id, "사용 횟수 또는 재사용 대기시간 조건을 만족하지 않습니다")
		return
	var required := 0
	if effect.definition.target_mode in [AugmentDefinition.TargetMode.OWN_PIECE, AugmentDefinition.TargetMode.ENEMY_PIECE]:
		required = 1
	if effect.definition.target_mode == AugmentDefinition.TargetMode.TWO_OWN_PIECES or augment_id == &"wizard":
		required = 2
	if target_ids.size() != required or (target_ids.size() == 2 and target_ids[0] == target_ids[1]):
		_reject_active_skill(player_id, "필요한 대상 수가 올바르지 않습니다")
		return
	for index in target_ids.size():
		var validated_piece: AlkkagiPiece = game().find_piece(target_ids[index])
		if validated_piece == null:
			_reject_active_skill(player_id, "대상 바둑알을 찾을 수 없습니다")
			return
		if augment_id == &"wizard":
			if (index == 0 and validated_piece.owner_id != player_id) or (index == 1 and validated_piece.owner_id == player_id):
				_reject_active_skill(player_id, "마법사 대상 순서가 올바르지 않습니다")
				return
		elif effect.definition.target_mode in [AugmentDefinition.TargetMode.OWN_PIECE, AugmentDefinition.TargetMode.TWO_OWN_PIECES] and validated_piece.owner_id != player_id:
			_reject_active_skill(player_id, "자신의 바둑알을 선택해야 합니다")
			return
		elif effect.definition.target_mode == AugmentDefinition.TargetMode.ENEMY_PIECE and validated_piece.owner_id == player_id:
			_reject_active_skill(player_id, "상대 바둑알을 선택해야 합니다")
			return
	if effect.definition.target_mode == AugmentDefinition.TargetMode.NONE:
		effect.activate_immediate(game(), player_id)
	elif effect.definition.target_mode == AugmentDefinition.TargetMode.BOARD_POSITION:
		if not effect.on_position_target(game(), player_id, board_position):
			_reject_active_skill(player_id, "해당 위치에는 설치할 수 없습니다")
	else:
		var applied := false
		for index in target_ids.size():
			var target_id: int = target_ids[index]
			var piece: AlkkagiPiece = game().find_piece(target_id)
			if piece == null:
				_reject_active_skill(player_id, "대상 바둑알이 사라졌습니다")
				return
			var accepted := effect.on_piece_target(game(), player_id, piece)
			if index == target_ids.size() - 1:
				applied = accepted
		if not applied:
			effect.cancel_active()
			_reject_active_skill(player_id, "선택한 대상에 스킬을 적용할 수 없습니다")

func _reject_active_skill(player_id: int, reason: String) -> void:
	if OS.is_debug_build():
		push_warning("[active-skill] rejected player %d: %s" % [player_id, reason])
	if player_id == 1:
		game().network_active_skill_rejected(reason)
	elif player_id == 2:
		var peer_id := _peer_for_player(2)
		if peer_id != 0:
			receive_active_skill_rejected.rpc_id(peer_id, reason)

func broadcast_projectile(from: Vector2, to: Vector2, color: Color, size: float) -> void:
	if mode == Mode.HOST:
		receive_projectile.rpc(from, to, color, size)

@rpc("authority", "call_remote", "reliable")
func receive_projectile(from: Vector2, to: Vector2, color: Color, size: float) -> void:
	if mode == Mode.CLIENT:
		game().animate_projectile(from, to, color, size, false)

@rpc("authority", "call_remote", "reliable")
func receive_lobby(data: Dictionary) -> void:
	if is_gdsync_mode() and GDSync.get_sender_id() != gdsync_host_id:
		return
	piece_count = int(data.get("piece_count", GameplayRules.DEFAULT_PIECES))
	ready_state = data.get("ready", {1: false, 2: false})
	connected_players = data.get("connected", {1: true, 2: true})
	lobby_updated.emit(data)

@rpc("authority", "call_remote", "reliable")
func receive_augment_offer(player_id: int, ids: Array[String], initial: bool, resume_player: int, stage: int, completed_round: int) -> void:
	game().network_receive_offer(player_id, ids, initial, resume_player, stage, completed_round)

@rpc("authority", "call_remote", "reliable")
func receive_augment_granted(player_id: int, augment_id: String) -> void:
	if not game().augment_manager.has_augment(player_id, StringName(augment_id)):
		game().augment_manager.acquire(game(), player_id, StringName(augment_id))
	game().network_augment_granted(player_id, StringName(augment_id))

@rpc("authority", "call_remote", "reliable")
func receive_world_start(count: int) -> void:
	match_active = true
	game().network_start_world(count)

@rpc("authority", "call_remote", "reliable")
func receive_selection_complete(stage: int, resume_player: int, completed_round: int) -> void:
	game().network_selection_complete(stage, resume_player, completed_round)

@rpc("authority", "call_remote", "reliable")
func receive_active_skill_rejected(reason: String) -> void:
	game().network_active_skill_rejected(reason)

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func receive_snapshot(snapshot: Dictionary) -> void:
	if mode == Mode.CLIENT:
		game().apply_network_snapshot(snapshot)

func _on_peer_connected(peer_id: int) -> void:
	if mode != Mode.HOST:
		return
	if bool(connected_players[2]):
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	peer_to_player[peer_id] = 2
	last_sequences.erase(peer_id)
	connected_players[2] = true
	ready_state[2] = false
	connection_message.emit("참가자가 연결되었습니다.", false)
	_broadcast_lobby()

func _on_peer_disconnected(peer_id: int) -> void:
	if shutting_down:
		return
	if mode == Mode.HOST:
		var player_id := _player_for_peer(peer_id)
		if player_id == 2:
			connected_players[2] = false
			ready_state[2] = false
			match_active = false
			peer_to_player.erase(peer_id)
			session_ended.emit("참가자의 연결이 끊겼습니다.")
			_broadcast_lobby()

func _on_connected_to_server() -> void:
	if mode != Mode.CLIENT:
		return
	connection_message.emit("호스트에 연결되었습니다.", false)

func _on_connection_failed() -> void:
	if mode == Mode.CLIENT:
		mode = Mode.OFFLINE
		connection_message.emit("호스트에 연결하지 못했습니다. IP, 포트, 방화벽을 확인하세요.", true)

func _on_server_disconnected() -> void:
	if mode == Mode.CLIENT and not shutting_down:
		mode = Mode.OFFLINE
		match_active = false
		session_ended.emit("호스트와의 연결이 끊겼습니다.")

func _lobby_data() -> Dictionary:
	return {"piece_count": piece_count, "ready": ready_state.duplicate(), "connected": connected_players.duplicate(), "host": 1}

func _emit_lobby() -> void:
	lobby_updated.emit(_lobby_data())

func _broadcast_lobby() -> void:
	var data := _lobby_data()
	if mode == Mode.GDSYNC_HOST:
		GDSync.call_func(receive_lobby, data)
	else:
		receive_lobby.rpc(data)
	lobby_updated.emit(data)

func _on_gdsync_lobby_created(lobby_name: String) -> void:
	if mode != Mode.GDSYNC_HOST or lobby_name != ROOM_PREFIX + room_code:
		return
	GDSync.lobby_join(lobby_name)

func _on_gdsync_lobby_creation_failed(lobby_name: String, error: int) -> void:
	if mode != Mode.GDSYNC_HOST or lobby_name != ROOM_PREFIX + room_code:
		return
	if error == ENUMS.LOBBY_CREATION_ERROR.LOBBY_ALREADY_EXISTS and room_create_attempts < ROOM_CREATE_ATTEMPTS:
		connection_message.emit("방 코드 충돌. 새 코드를 발급합니다…", false)
		await get_tree().create_timer(3.1).timeout
		if mode == Mode.GDSYNC_HOST:
			_create_online_room_attempt()
		return
	var reason: String = str(ENUMS.LOBBY_CREATION_ERROR.keys()[error]) if error >= 0 and error < ENUMS.LOBBY_CREATION_ERROR.size() else "UNKNOWN"
	mode = Mode.OFFLINE
	connection_message.emit("온라인 방 생성 실패: %s (error=%d)" % [reason, error], true)

func _on_gdsync_lobby_joined(lobby_name: String) -> void:
	if OS.is_debug_build():
		print("[gdsync] lobby_joined name=%s expected=%s mode=%s host=%d self=%d" % [lobby_name, ROOM_PREFIX + room_code, Mode.keys()[mode], GDSync.get_host(), GDSync.get_client_id()])
	if not is_gdsync_mode() or lobby_name != ROOM_PREFIX + room_code:
		return
	var own_id := GDSync.get_client_id()
	if mode == Mode.GDSYNC_HOST:
		gdsync_host_id = own_id
		mode = Mode.GDSYNC_HOST
		local_player_id = 1
		peer_to_player = {own_id: 1}
		connected_players = {1: true, 2: false}
		connection_message.emit("온라인 방 생성 완료 · 코드 %s" % room_code, false)
	else:
		gdsync_host_id = GDSync.get_host()
		mode = Mode.GDSYNC_CLIENT
		local_player_id = 2
		peer_to_player = {gdsync_host_id: 1, own_id: 2}
		connected_players = {1: true, 2: true}
		connection_message.emit("온라인 방 %s에 참가했습니다." % room_code, false)
	_emit_lobby()

func _on_gdsync_lobby_join_failed(lobby_name: String, error: int) -> void:
	if OS.is_debug_build():
		print("[gdsync] lobby_join_failed name=%s error=%d mode=%s" % [lobby_name, error, Mode.keys()[mode]])
	if mode != Mode.GDSYNC_CLIENT or lobby_name != ROOM_PREFIX + room_code:
		return
	var reason: String = str(ENUMS.LOBBY_JOIN_ERROR.keys()[error]) if error >= 0 and error < ENUMS.LOBBY_JOIN_ERROR.size() else "UNKNOWN"
	mode = Mode.OFFLINE
	connection_message.emit("온라인 방 참가 실패: %s (error=%d)" % [reason, error], true)

func _on_gdsync_client_joined(client_id: int) -> void:
	if not is_gdsync_mode() or client_id == GDSync.get_client_id():
		return
	if mode == Mode.GDSYNC_HOST:
		if bool(connected_players[2]):
			GDSync.lobby_kick_client(client_id, "이 방은 2인 전용입니다.")
			return
		peer_to_player[client_id] = 2
		connected_players[2] = true
		ready_state[2] = false
		connection_message.emit("친구가 온라인 방에 참가했습니다.", false)
		_broadcast_lobby()

func _on_gdsync_client_left(client_id: int) -> void:
	if not is_gdsync_mode() or shutting_down:
		return
	var player_id := _player_for_peer(client_id)
	peer_to_player.erase(client_id)
	if mode == Mode.GDSYNC_HOST and player_id == 2:
		connected_players[2] = false
		ready_state[2] = false
		match_active = false
		session_ended.emit("참가자의 연결이 끊겼습니다.")
		_broadcast_lobby()
	elif mode == Mode.GDSYNC_CLIENT and client_id == gdsync_host_id:
		mode = Mode.OFFLINE
		match_active = false
		session_ended.emit("방장이 방을 나갔거나 연결이 끊겼습니다.")

func _on_gdsync_host_changed(_is_host: bool, new_host_id: int) -> void:
	if OS.is_debug_build():
		print("[gdsync] host_changed new=%d tracked=%d mode=%s" % [new_host_id, gdsync_host_id, Mode.keys()[mode]])
	if mode == Mode.GDSYNC_CLIENT:
		if gdsync_host_id < 0:
			gdsync_host_id = new_host_id
			peer_to_player.erase(-1)
			peer_to_player[new_host_id] = 1
			connected_players[1] = true
			_emit_lobby()
		elif new_host_id != gdsync_host_id:
			mode = Mode.OFFLINE
			match_active = false
			session_ended.emit("방장 연결이 끊겨 온라인 대전을 종료합니다.")

func _on_gdsync_disconnected() -> void:
	gdsync_connected = false
	if is_gdsync_mode() and not shutting_down:
		mode = Mode.OFFLINE
		match_active = false
		session_ended.emit("GD-Sync 서버와 연결이 끊겼습니다.")

func _on_gdsync_connected() -> void:
	gdsync_connected = true
