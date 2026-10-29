extends SceneTree

var failures := 0
var lobby_lettering: Texture2D

func _init() -> void:
	call_deferred("run_test")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func check_no_lobby_art(node: Node, label: String) -> void:
	if node is TextureRect:
		check(node.texture != lobby_lettering, label + " excludes baked lobby lettering")
	check(not node is OnlineLobby, label + " excludes lobby scene")
	for child in node.get_children():
		check_no_lobby_art(child, label)

func run_test() -> void:
	lobby_lettering = load("res://assets/ui/ink/title_swash.png")
	check(InkStyle.SWASH_TEXTURE != lobby_lettering, "shared decoration is separate from lobby title")
	check(InkStyle.SWASH_TEXTURE.resource_path == "res://assets/ui/swash.png", "shared decoration uses existing text-free brush")
	check(InkStyle.swash_box().texture == InkStyle.SWASH_TEXTURE, "label decorations use text-free brush")
	for is_host in [true, false]:
		var game: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		await process_frame
		game.set_physics_process(false)
		game.online_mode = true
		game.online_is_host = is_host
		game.local_player_id = 1 if is_host else 2
		game.state_machine.transition(GameStateMachine.State.LOBBY)
		game._show_online_lobby()
		var lobby: OnlineLobby = game.screen_root
		var title := lobby.find_child("LobbyTitleArt", true, false) as TextureRect
		check(title != null and title.is_visible_in_tree(), "lobby title visible for either role")
		var atlas := title.texture as AtlasTexture
		check(atlas != null and atlas.region == Rect2(18, 78, 818, 154), "original lobby title art preserved")
		game.network_prepare_match(is_host, game.local_player_id, 3)
		game.network_start_world(3)
		check(not title.is_inside_tree(), "lobby title detaches immediately on game start")
		check_no_lobby_art(game.ui, "placement")
		var choices: Array[AugmentDefinition] = []
		choices.append(load("res://resources/augments/gravity_field.tres"))
		choices.append(load("res://resources/augments/blizzard.tres"))
		choices.append(load("res://resources/augments/wizard.tres"))
		var selection: AugmentSelection = load("res://scenes/ui/augment_selection.tscn").instantiate()
		selection.setup("Player", Color.WHITE, choices, true, 0)
		game.set_screen(selection)
		check_no_lobby_art(game.ui, "augment selection")
		# A late lobby update must not replace the current gameplay screen.
		game.state_machine.transition(GameStateMachine.State.INITIAL_AUGMENT_SELECTION)
		game._on_network_lobby_updated({})
		check(game.screen_root == selection, "late lobby update does not resurrect title")
		game.build_hud()
		game.state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
		check_no_lobby_art(game.ui, "combat")
		for winner in [1, 2]:
			var toss := CoinTossVisual.new()
			game.hud.add_child(toss)
			toss.play(func(): return winner)
			check(toss._swash.texture == InkStyle.SWASH_TEXTURE, "both coin outcomes use generic decoration")
			check_no_lobby_art(game.ui, "coin toss")
			await toss.finished
			check_no_lobby_art(game.ui, "coin result")
			toss.queue_free()
			await process_frame
		for player in [1, 2]:
			game.current_player = player
			game.round_count += 1
			game.build_hud()
			check_no_lobby_art(game.ui, "turn and round transition")
		game.show_game_over(1)
		check_no_lobby_art(game.ui, "game over")
		game.state_machine.transition(GameStateMachine.State.LOBBY)
		game._show_online_lobby()
		var returned_title := game.screen_root.find_child("LobbyTitleArt", true, false) as TextureRect
		check(returned_title != null and returned_title.is_visible_in_tree(), "returning lobby restores title")
		game.queue_free()
		await process_frame
	if failures == 0:
		print("PASS: lobby-only title, placement, selection, both coin outcomes, combat, rounds, return and late updates for host/client roles")
	quit(failures)
