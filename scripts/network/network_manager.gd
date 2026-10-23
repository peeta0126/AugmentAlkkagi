class_name AlkkagiNetworkManager
extends Node

signal lobby_updated(data: Dictionary)
signal connection_message(text: String, is_error: bool)
signal session_ended(reason: String)

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 1
const SNAPSHOT_INTERVAL := 0.05
const PROTOCOL_VERSION := 2

enum Mode { OFFLINE, HOST, CLIENT }

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

func _ready() -> void:
	name = "NetworkManager"
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func game() -> Node:
	return get_parent()

func create_host(port: int = DEFAULT_PORT) -> Error:
	shutdown(false)
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

func shutdown(notify: bool = true) -> void:
	if mode == Mode.OFFLINE:
		return
	shutting_down = true
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.OFFLINE
	local_player_id = 0
	match_active = false
	offers.clear()
	selection_context.clear()
	pending_choices.clear()
	selection_completed = {1: false, 2: false}
	shutting_down = false
	if notify:
		session_ended.emit("네트워크 방에서 나왔습니다.")

func is_online() -> bool:
	return mode != Mode.OFFLINE

func is_host() -> bool:
	return mode == Mode.HOST

func set_ready(value: bool) -> void:
	if mode == Mode.HOST:
		ready_state[1] = value
		_broadcast_lobby()
	elif mode == Mode.CLIENT:
		request_lobby_ready.rpc_id(1, value, PROTOCOL_VERSION)

func set_piece_count(value: int) -> void:
	if mode != Mode.HOST or match_active:
		return
	piece_count = GameplayRules.clamp_piece_count(value)
	_broadcast_lobby()

func can_start() -> bool:
	return mode == Mode.HOST and bool(connected_players[1]) and bool(connected_players[2]) and bool(ready_state[1]) and bool(ready_state[2])

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
		return
	active_selection_stage += 1
	offers.clear()
	pending_choices.clear()
	selection_completed = {1: false, 2: false}
	selection_context = {"initial": initial, "resume": resume_player, "round": completed_round}
	_begin_selection(2, initial, resume_player)
	_begin_selection(1, initial, resume_player)

func _begin_selection(player_id: int, initial: bool, resume_player: int) -> void:
	if mode != Mode.HOST:
		return
	var definitions: Array[AugmentDefinition] = game().augment_manager.get_choices(player_id, 3)
	var ids: Array[String] = []
	for definition in definitions:
		ids.append(str(definition.id))
	offers[player_id] = {"stage": active_selection_stage, "ids": ids}
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

func _valid_sequence(peer_id: int, sequence: int) -> bool:
	var previous := int(last_sequences.get(peer_id, 0))
	if sequence <= previous:
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
	if mode != Mode.HOST:
		return
	var sender := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL_VERSION:
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
	if _valid_sequence(sender, sequence):
		_host_process_shot(_player_for_peer(sender), piece_id, pull_vector, sequence)

func _host_process_shot(player_id: int, piece_id: int, pull_vector: Vector2, _sequence: int) -> void:
	if mode != Mode.HOST or player_id == 0 or not match_active:
		return
	game().network_execute_shot(player_id, piece_id, pull_vector)

@rpc("any_peer", "call_remote", "reliable")
func request_augment_choice(stage: int, augment_id: String, sequence: int) -> void:
	if mode != Mode.HOST:
		return
	var sender := multiplayer.get_remote_sender_id()
	if _valid_sequence(sender, sequence):
		_host_process_augment_choice(_player_for_peer(sender), stage, StringName(augment_id), sequence)

func _host_process_augment_choice(player_id: int, stage: int, augment_id: StringName, _sequence: int) -> void:
	if mode != Mode.HOST or not match_active or player_id not in [1, 2] or stage != active_selection_stage:
		return
	if bool(selection_completed.get(player_id, false)) or not offers.has(player_id) or not game().augment_manager.can_acquire(player_id):
		return
	var offer: Dictionary = offers[player_id]
	if int(offer.get("stage", -1)) != stage or not str(augment_id) in offer.get("ids", []):
		return
	pending_choices[player_id] = augment_id
	selection_completed[player_id] = true
	if not (bool(selection_completed[1]) and bool(selection_completed[2])):
		return
	for selected_player in [1, 2]:
		var selected_id: StringName = pending_choices.get(selected_player, StringName())
		if selected_id == StringName() or not game().augment_manager.can_acquire(selected_player):
			return
	for selected_player in [1, 2]:
		var selected_id: StringName = pending_choices[selected_player]
		if not game().augment_manager.acquire(game(), selected_player, selected_id):
			return
		receive_augment_granted.rpc(selected_player, str(selected_id))
		game().network_augment_granted(selected_player, selected_id)
	var initial := bool(selection_context.get("initial", false))
	var resume := int(selection_context.get("resume", 1))
	var completed_round := int(selection_context.get("round", 0))
	offers.clear()
	pending_choices.clear()
	if initial:
		receive_world_start.rpc(piece_count)
		game().network_start_world(piece_count)
	else:
		receive_selection_complete.rpc(stage, resume, completed_round)
		game().network_selection_complete(stage, resume, completed_round)

@rpc("any_peer", "call_remote", "reliable")
func request_active_skill(augment_id: String, target_ids: Array[int], board_position: Vector2, sequence: int) -> void:
	if mode != Mode.HOST:
		return
	var sender := multiplayer.get_remote_sender_id()
	if _valid_sequence(sender, sequence):
		_host_process_active(_player_for_peer(sender), StringName(augment_id), target_ids, board_position, sequence)

func _host_process_active(player_id: int, augment_id: StringName, target_ids: Array[int], board_position: Vector2, _sequence: int) -> void:
	if mode != Mode.HOST or player_id != game().current_player or not game().state_machine.allows_aiming():
		return
	var effect: AugmentEffect
	for candidate: AugmentEffect in game().augment_manager.effects[player_id]:
		if candidate.definition.id == augment_id:
			effect = candidate
			break
	if effect == null or not effect.can_activate(game(), player_id):
		return
	var required := 0
	if effect.definition.target_mode in [AugmentDefinition.TargetMode.OWN_PIECE, AugmentDefinition.TargetMode.ENEMY_PIECE]:
		required = 1
	if effect.definition.target_mode == AugmentDefinition.TargetMode.TWO_OWN_PIECES or augment_id == &"wizard":
		required = 2
	if target_ids.size() != required or (target_ids.size() == 2 and target_ids[0] == target_ids[1]):
		return
	for index in target_ids.size():
		var validated_piece: AlkkagiPiece = game().find_piece(target_ids[index])
		if validated_piece == null:
			return
		if augment_id == &"wizard":
			if (index == 0 and validated_piece.owner_id != player_id) or (index == 1 and validated_piece.owner_id == player_id):
				return
		elif effect.definition.target_mode in [AugmentDefinition.TargetMode.OWN_PIECE, AugmentDefinition.TargetMode.TWO_OWN_PIECES] and validated_piece.owner_id != player_id:
			return
		elif effect.definition.target_mode == AugmentDefinition.TargetMode.ENEMY_PIECE and validated_piece.owner_id == player_id:
			return
	if effect.definition.target_mode == AugmentDefinition.TargetMode.NONE:
		effect.activate_immediate(game(), player_id)
	elif effect.definition.target_mode == AugmentDefinition.TargetMode.BOARD_POSITION:
		effect.on_position_target(game(), player_id, board_position)
	else:
		for target_id in target_ids:
			var piece: AlkkagiPiece = game().find_piece(target_id)
			if piece == null:
				return
			effect.on_piece_target(game(), player_id, piece)

func broadcast_projectile(from: Vector2, to: Vector2, color: Color, size: float) -> void:
	if mode == Mode.HOST:
		receive_projectile.rpc(from, to, color, size)

@rpc("authority", "call_remote", "reliable")
func receive_projectile(from: Vector2, to: Vector2, color: Color, size: float) -> void:
	if mode == Mode.CLIENT:
		game().animate_projectile(from, to, color, size, false)

@rpc("authority", "call_remote", "reliable")
func receive_lobby(data: Dictionary) -> void:
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
	receive_lobby.rpc(data)
	lobby_updated.emit(data)
