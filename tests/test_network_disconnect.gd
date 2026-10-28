## GD-Sync 종료 뒤 로비, 선택 단계, 규칙, 스냅샷 캐시가 초기화되는지 검증한다.
extends SceneTree

var failures := 0
var reasons: Array[String] = []

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func dirty_session(nm: Node) -> void:
	nm.offers = {1: ["tank"], 2: ["train"]}
	nm.pending_choices = {1: "tank"}
	nm.selection_context = {"initial": true}
	nm.active_selection_stage = 4
	nm.selection_completed = {1: true, 2: false}
	nm.selection_pick_counts = {1: 1, 2: 0}
	nm.selection_pick_targets = {1: 2, 2: 2}
	nm.selection_refresh_used = {1: true, 2: false}
	nm.placement_completed = {1: true, 2: true}
	nm.refresh_mode = true
	nm.chaos_mode = true
	nm.room_code = "123456"
	nm.match_active = true
	nm.last_fast_bytes = PackedByteArray([1])
	nm.last_slow_bytes = PackedByteArray([2])

func session_is_clean(nm: Node) -> bool:
	return nm.offers.is_empty() and nm.pending_choices.is_empty() and nm.selection_context.is_empty() \
		and nm.active_selection_stage == 0 and nm.selection_completed == {1: false, 2: false} \
		and nm.selection_pick_counts == {1: 0, 2: 0} and nm.selection_pick_targets == {1: 1, 2: 1} \
		and nm.selection_refresh_used == {1: false, 2: false} and nm.placement_completed == {1: false, 2: false} \
		and not nm.refresh_mode and not nm.chaos_mode and nm.room_code.is_empty() \
		and nm.last_fast_bytes.is_empty() and nm.last_slow_bytes.is_empty()

func run_test() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var nm: Node = game.network_manager
	nm.session_ended.connect(func(reason: String) -> void: reasons.append(reason))

	nm.mode = nm.Mode.CLIENT
	nm.gdsync_host_id = 77
	dirty_session(nm)
	nm._on_gdsync_client_left(77)
	check(reasons.size() == 1 and "방장" in reasons[0], "guest is told that the host left")
	check(nm.mode == nm.Mode.OFFLINE and not nm.match_active, "guest leaves the online match")
	check(session_is_clean(nm) and nm.gdsync_host_id == -1, "guest drops stale session state")

	reasons.clear()
	nm.mode = nm.Mode.HOST
	nm.gdsync_host_id = 11
	nm.peer_to_player = {11: 1, 66: 2}
	nm.connected_players = {1: true, 2: true}
	dirty_session(nm)
	nm._on_gdsync_client_left(66)
	check(reasons.size() == 1 and "참가자" in reasons[0], "host is told that the guest left")
	check(not bool(nm.connected_players[2]) and not nm.match_active, "host reopens the guest slot")
	check(nm.offers.is_empty() and nm.last_fast_bytes.is_empty(), "host clears selection and snapshot caches")

	reasons.clear()
	nm.mode = nm.Mode.OFFLINE
	dirty_session(nm)
	nm.shutdown(false)
	check(reasons.is_empty(), "shutdown(false) stays silent")
	check(session_is_clean(nm), "shutdown also cleans stale state after mode was already set offline")

	nm._reset_lobby_state()
	check(nm.ready_state == {1: false, 2: false} and nm.connected_players == {1: true, 2: false}, "a new room starts with clean ready state")

	if failures == 0:
		print("PASS: GD-Sync disconnects reset the complete session")
	quit(failures)
