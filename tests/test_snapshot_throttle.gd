## GD-Sync 스냅샷 억제, reliable 부가 상태 분리, 직렬화 크기를 검증한다.
extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func run_test() -> void:
	var host := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var guest := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(host)
	root.add_child(guest)
	await process_frame
	for game in [host, guest]:
		game.starting_piece_count = 5
		game.start_game()
	host.online_mode = true
	host.online_is_host = true
	guest.online_mode = true
	guest.online_is_host = false
	guest.local_player_id = 2
	await process_frame
	for player_id in [1, 2]:
		for augment_id in [&"tank", &"train", &"wall_maria"]:
			host.augment_manager.acquire(host, player_id, augment_id)
	var nm: Node = host.network_manager
	nm._reset_snapshot_cache()

	var full_snapshot: Dictionary = host.create_network_snapshot()
	var first: Dictionary = nm._next_snapshot()
	var full_bytes := var_to_bytes(full_snapshot).size()
	var fast_bytes := var_to_bytes(first).size()
	var extras_bytes := var_to_bytes(nm.pending_extras).size()
	check(not first.is_empty(), "first movement snapshot is sent")
	check(not first.has("effects") and not first.has("walls"), "movement snapshots exclude effects and walls")
	check(nm.pending_extras.has("effects") and nm.pending_extras.has("walls"), "first tick queues reliable world extras")
	check(fast_bytes < full_bytes, "split movement snapshot is smaller than the legacy full snapshot")
	guest.apply_network_snapshot(first, 0.05)
	guest.apply_network_extras(nm.pending_extras["effects"], nm.pending_extras["walls"])
	check(guest.augment_manager.has_augment(1, &"tank"), "guest receives host augments through world extras")

	for repeat_index in 2:
		var repeat: Dictionary = nm._next_snapshot()
		check(not repeat.is_empty(), "movement snapshot repeats after change (%d)" % repeat_index)
		check(nm.pending_extras.is_empty(), "unchanged world extras are not repeated (%d)" % repeat_index)

	var idle_sent := 0
	for tick in 30:
		if not nm._next_snapshot().is_empty():
			idle_sent += 1
		check(nm.pending_extras.is_empty(), "idle tick does not queue world extras (%d)" % tick)
	check(idle_sent == 1, "idle board sends one heartbeat in 1.5 seconds (sent %d)" % idle_sent)

	host.get_pieces()[0].position += Vector2(5.0, 0.0)
	var moved: Dictionary = nm._next_snapshot()
	check(not moved.is_empty(), "piece movement is sent immediately")
	check(nm.pending_extras.is_empty(), "piece movement does not resend unchanged extras")
	guest.apply_network_snapshot(moved, 0.05)
	check(guest.augment_manager.has_augment(1, &"tank"), "guest keeps augment state after a fast-only snapshot")

	nm._next_snapshot()
	nm._next_snapshot()
	for effect: AugmentEffect in host.augment_manager.effects[1]:
		if effect.definition.id == &"tank":
			effect.uses_left = 7 if effect.uses_left != 7 else 6
	nm._next_snapshot()
	check(nm.pending_extras.has("effects"), "changed effect state queues reliable extras")
	nm._next_snapshot()
	check(nm.pending_extras.is_empty(), "reliable extras are queued only once")

	nm._reset_snapshot_cache()
	nm._next_snapshot()
	check(nm.pending_extras.has("effects"), "cache reset forces a complete extras refresh")

	if failures == 0:
		print("SNAPSHOT_BYTES: full=%d fast=%d extras=%d idle_sends_1_5s=%d" % [full_bytes, fast_bytes, extras_bytes, idle_sent])
		print("PASS: GD-Sync snapshots throttle idle traffic and split reliable world extras")
	quit(failures)
