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

func reset_pair(host: Node, guest: Node) -> void:
	for game in [host, guest]:
		game.clear_world()
		game.augment_manager.reset_match()
		game.reset_runtime_effects()
		game.start_game_world()
	guest.online_mode = true
	guest.online_is_host = false
	guest.local_player_id = 2
	await process_frame

func sync_snapshot(host: Node, guest: Node) -> void:
	var snapshot: Dictionary = host.create_network_snapshot()
	var effects: Dictionary = snapshot["effects"]
	var walls: PackedFloat32Array = snapshot["walls"]
	snapshot.erase("effects")
	snapshot.erase("walls")
	guest.apply_network_snapshot(snapshot, 0.05)
	guest.apply_network_extras(effects, walls)
	await process_frame

func run_test() -> void:
	var host := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var guest := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(host)
	root.add_child(guest)
	await process_frame

	# Existing changed field ability: lantern placement/runtime visual reaches the guest.
	await reset_pair(host, guest)
	host.augment_manager.acquire(host, 1, &"lantern")
	var lantern: LanternAugmentEffect = find_effect(host, 1, &"lantern")
	lantern.on_position_target(host, 1, AlkkagiBoard.BOARD_RECT.get_center())
	await sync_snapshot(host, guest)
	var guest_lantern: LanternAugmentEffect = find_effect(guest, 1, &"lantern")
	check(guest_lantern != null and guest_lantern.installed, "lantern runtime state reaches guest")
	check(guest.board.field_visuals.has("lantern_1"), "lantern field visual reaches guest")

	# Gravity runtime and circular field use the same existing snapshot channel.
	await reset_pair(host, guest)
	host.augment_manager.acquire(host, 1, &"gravity_field")
	var gravity: GravityFieldAugmentEffect = find_effect(host, 1, &"gravity_field")
	gravity.after_shot(host, 1, host.get_pieces()[0])
	await sync_snapshot(host, guest)
	var guest_gravity: GravityFieldAugmentEffect = find_effect(guest, 1, &"gravity_field")
	check(guest_gravity != null and guest_gravity.active, "gravity field runtime reaches guest")
	check(guest.board.field_visuals.has("gravity_1"), "gravity field visual reaches guest")

	# Stealth keeps physics data while only the opponent viewer hides the target.
	await reset_pair(host, guest)
	host.augment_manager.acquire(host, 1, &"stealth")
	var host_hidden: AlkkagiPiece = host.get_pieces()[0]
	find_effect(host, 1, &"stealth").on_piece_target(host, 1, host_hidden)
	await sync_snapshot(host, guest)
	var guest_hidden: AlkkagiPiece = guest.find_piece(host_hidden.piece_id)
	check(guest_hidden != null and not guest_hidden.visible and guest_hidden.hidden_from_player == 2, "stealth hides only the opponent's rendered stone")
	check(guest_hidden.collision_layer == 1 and guest_hidden.freeze, "stealth preserves guest collision state and host authority")

	# Earthquake lines and wish balls/collection counts are reproduced exactly.
	await reset_pair(host, guest)
	host.augment_manager.acquire(host, 1, &"earthquake")
	var earthquake: EarthquakeAugmentEffect = find_effect(host, 1, &"earthquake")
	earthquake.activate_immediate(host, 1)
	await sync_snapshot(host, guest)
	var guest_quake: EarthquakeAugmentEffect = find_effect(guest, 1, &"earthquake")
	check(guest_quake != null and guest_quake.cracks.size() == earthquake.cracks.size(), "earthquake crack layout reaches guest")
	check(guest.board.field_visuals.has("earthquake_1"), "earthquake visual reaches guest")
	var guest_quake_visual: EarthquakeVisual = guest.board.field_visual_nodes.get("earthquake_1") as EarthquakeVisual
	var guest_runtime_cracks: Array[Node] = []
	if guest_quake_visual != null:
		guest_runtime_cracks.assign(guest_quake_visual.cracks_root.get_children().filter(func(child: Node): return child != guest_quake_visual.crack_template))
	check(guest_runtime_cracks.size() == earthquake.cracks.size(), "guest duplicates one CrackTemplate per synchronized crack")
	if not guest_runtime_cracks.is_empty():
		var guest_sprite := guest_runtime_cracks[0].get_node_or_null("CrackSprite") as Sprite2D
		check(guest_sprite != null and guest_sprite.is_visible_in_tree() and guest_sprite.texture != null, "guest renders the synchronized earthquake PNG")

	await reset_pair(host, guest)
	host.augment_manager.acquire(host, 1, &"wish")
	var wish: WishAugmentEffect = find_effect(host, 1, &"wish")
	wish.activate_immediate(host, 1)
	await sync_snapshot(host, guest)
	var guest_wish: WishAugmentEffect = find_effect(guest, 1, &"wish")
	check(guest_wish != null and guest_wish.balls == wish.balls and guest_wish.collected == 0, "dragon ball positions and collection count reach guest")
	check(guest.board.field_visuals.has("wish_1"), "dragon ball visuals reach guest")

	# Passive train phase and its host-selected warning path share the effect runtime snapshot.
	await reset_pair(host, guest)
	host.augment_manager.acquire(host, 1, &"train")
	var host_train: TrainAugmentEffect = find_effect(host, 1, &"train")
	host_train.on_global_turn_ended(host, 1)
	await sync_snapshot(host, guest)
	var guest_train: TrainAugmentEffect = find_effect(guest, 1, &"train")
	check(guest_train != null and guest_train.phase == TrainAugmentEffect.Phase.WARNING, "train passive phase reaches guest")
	check(guest_train.warned_path == host_train.warned_path and guest.board.field_visuals.has("train_warning_1"), "host-selected train warning path reaches guest")

	# Blindness is synchronized as state but rendered only for the targeted local viewer.
	await reset_pair(host, guest)
	host.current_player = 2
	host.apply_blind(2, 1)
	await sync_snapshot(host, guest)
	check(guest.blind_material != null and guest.blind_visual != null, "blindness veil is created on the targeted guest only")
	check(host.blind_material == null, "blindness does not cover the opponent host view")

	host.queue_free()
	guest.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: version 2 augment host-to-guest GD-Sync synchronization")
	quit(failures)
