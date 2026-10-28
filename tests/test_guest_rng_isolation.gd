## 무작위 증강 결과가 호스트에서만 결정되고 참가자는 결과만 적용하는지 검증한다.
extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func find_effect(game: Node, player_id: int, augment_id: StringName) -> AugmentEffect:
	for effect: AugmentEffect in game.augment_manager.effects[player_id]:
		if effect.definition.id == augment_id:
			return effect
	return null

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
	host.local_player_id = 1
	guest.online_mode = true
	guest.online_is_host = false
	guest.local_player_id = 2
	await process_frame

	host.augment_manager.rng.seed = 11
	guest.augment_manager.rng.seed = 99999
	var guest_state_before: int = guest.augment_manager.rng.state
	for augment_id in [&"earthquake", &"wish", &"train"]:
		host.augment_manager.acquire(host, 1, augment_id)
	for augment_id in [&"janggi", &"dodge", &"triple_shot"]:
		host.augment_manager.acquire(host, 2, augment_id)

	var host_state_before: int = host.augment_manager.rng.state
	(find_effect(host, 1, &"earthquake") as EarthquakeAugmentEffect).activate_immediate(host, 1)
	(find_effect(host, 1, &"wish") as WishAugmentEffect).activate_immediate(host, 1)
	var train := find_effect(host, 1, &"train") as TrainAugmentEffect
	train.phase = TrainAugmentEffect.Phase.PREVIEW
	train.on_global_turn_ended(host, 1)
	var target: AlkkagiPiece
	for piece in host.get_pieces():
		if piece.owner_id == 2:
			target = piece
			break
	find_effect(host, 2, &"janggi").on_piece_target(host, 2, target)
	check(host.augment_manager.rng.state != host_state_before, "host consumed random numbers")

	var snapshot: Dictionary = host.create_network_snapshot()
	var effects: Dictionary = snapshot["effects"]
	var walls: PackedFloat32Array = snapshot["walls"]
	snapshot.erase("effects")
	snapshot.erase("walls")
	guest.apply_network_snapshot(snapshot, 0.05)
	guest.apply_network_extras(effects, walls)
	await process_frame
	for index in 10:
		await physics_frame

	for pair in [[1, &"earthquake"], [1, &"wish"], [1, &"train"]]:
		var host_effect_state: Dictionary = find_effect(host, pair[0], pair[1]).network_state()
		var guest_effect := find_effect(guest, pair[0], pair[1])
		check(guest_effect != null, "%s reaches the guest" % pair[1])
		if guest_effect != null:
			check(guest_effect.network_state() == host_effect_state, "%s result is identical" % pair[1])
	var host_target: AlkkagiPiece = host.find_piece(target.piece_id)
	var guest_target: AlkkagiPiece = guest.find_piece(target.piece_id)
	check(guest_target != null and guest_target.transformation == host_target.transformation and not host_target.transformation.is_empty(), "janggi transformation is identical")
	check(guest.augment_manager.rng.state == guest_state_before, "guest did not consume local random numbers")

	if failures == 0:
		print("PASS: random augment results are host-authoritative")
	quit(failures)
