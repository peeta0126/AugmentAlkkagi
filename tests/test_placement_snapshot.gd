## 참가자가 돌을 배치하는 중에 호스트 스냅샷이 와도 내 돌은 되돌아가지 않고, 상대 돌만 따라가는지 확인
extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func run_test() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.online_mode = true
	game.online_is_host = false
	game.local_player_id = 2
	game.starting_piece_count = 3
	game.start_placement_world()
	await process_frame
	var snapshot: Dictionary = game.create_network_snapshot()
	var states: PackedFloat32Array = snapshot["pieces"]
	var own_id := -1
	var other_id := -1
	for offset in range(0, states.size(), 19):
		var owner := int(states[offset + 1])
		if owner == 2 and own_id < 0:
			own_id = int(states[offset])
		elif owner == 1 and other_id < 0:
			other_id = int(states[offset])
	var own: AlkkagiPiece = game.find_piece(own_id)
	var other: AlkkagiPiece = game.find_piece(other_id)
	var own_before := own.position
	var other_before := other.position
	# 호스트 쪽 옛 자리라고 가정하고 두 돌의 좌표를 바꾼 스냅샷을 만든다.
	for offset in range(0, states.size(), 19):
		var piece_id := int(states[offset])
		if piece_id == own_id or piece_id == other_id:
			states[offset + 2] += 37.0
	snapshot["pieces"] = states
	game.apply_network_snapshot(snapshot, 0.0)
	for _i in 30:
		await physics_frame
	check(own.position.distance_to(own_before) < 1.0, "own piece is not pulled by a snapshot during placement")
	check(other.position.distance_to(other_before) > 20.0, "opponent piece still follows the host snapshot")
	if failures == 0:
		print("PASS: placement snapshots leave the guest's own pieces alone")
	quit(failures)
