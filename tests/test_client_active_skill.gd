extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func prepare_client_turn(game: Node, augment_id: StringName) -> AugmentEffect:
	game.start_game()
	game.online_mode = true
	game.online_is_host = false
	game.local_player_id = 2
	game.current_player = 2
	game.state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
	check(game.augment_manager.acquire(game, 2, augment_id), "client acquires %s" % augment_id)
	game.build_hud()
	for effect: AugmentEffect in game.augment_manager.effects[2]:
		if effect.definition.id == augment_id:
			return effect
	return null

func press_active_button(game: Node, effect: AugmentEffect) -> void:
	var button: Button
	for candidate in game.hud.find_children("*", "Button", true, false):
		if candidate is Button and effect.definition.display_name in candidate.text:
			button = candidate
			break
	check(button != null, "%s button is present" % effect.definition.id)
	if button:
		button.pressed.emit()

func verify_snapshot_does_not_cancel_targeting(game: Node, label: String) -> void:
	var snapshot: Dictionary = game.create_network_snapshot()
	snapshot["state"] = int(GameStateMachine.State.PLAYER_AIMING)
	snapshot["current_player"] = 2
	game.apply_network_snapshot(snapshot)
	check(game.state_machine.current == GameStateMachine.State.SKILL_TARGETING, "%s targeting survives host aiming snapshot" % label)

func run_test() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame

	var snowball := prepare_client_turn(game, &"snowball")
	press_active_button(game, snowball)
	check(game.state_machine.current == GameStateMachine.State.SKILL_TARGETING, "snowball button enters targeting")
	verify_snapshot_does_not_cancel_targeting(game, "snowball")
	var own_piece: AlkkagiPiece
	var enemy_piece: AlkkagiPiece
	for piece in game.get_pieces():
		if piece.owner_id == 2 and own_piece == null:
			own_piece = piece
		elif piece.owner_id == 1 and enemy_piece == null:
			enemy_piece = piece
	game._on_piece_pressed(own_piece)
	check(game.network_skill_targets.is_empty(), "snowball rejects an allied target locally")
	game._on_piece_pressed(enemy_piece)
	check(game.network_skill_targets == [enemy_piece.piece_id], "snowball accepts an enemy target")

	var greatsword := prepare_client_turn(game, &"greatsword")
	press_active_button(game, greatsword)
	check(game.state_machine.current == GameStateMachine.State.SKILL_TARGETING, "greatsword button enters targeting")
	verify_snapshot_does_not_cancel_targeting(game, "greatsword")
	own_piece = null
	enemy_piece = null
	for piece in game.get_pieces():
		if piece.owner_id == 2 and own_piece == null:
			own_piece = piece
		elif piece.owner_id == 1 and enemy_piece == null:
			enemy_piece = piece
	game._on_piece_pressed(enemy_piece)
	check(game.network_skill_targets.is_empty(), "greatsword rejects an enemy target locally")
	game._on_piece_pressed(own_piece)
	check(game.network_skill_targets == [own_piece.piece_id], "greatsword accepts an allied target")

	var wall := prepare_client_turn(game, &"wall_maria")
	press_active_button(game, wall)
	check(game.state_machine.current == GameStateMachine.State.SKILL_TARGETING, "wall maria button enters targeting")
	verify_snapshot_does_not_cancel_targeting(game, "wall maria")
	game.confirm_board_position_skill(AlkkagiBoard.BOARD_RECT.get_center())
	check(game.state_machine.current == GameStateMachine.State.SKILL_TARGETING, "wall maria board click follows the client RPC path")

	if failures == 0:
		print("PASS: client active-skill button and targeting tests")
	quit(failures)
