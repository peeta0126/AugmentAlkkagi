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
	game.clear_world()
	game.augment_manager.reset_match()
	game.reset_runtime_effects()
	game.start_game_world(true)
	game.activate_gameplay_after_placement()
	await process_frame
	var toss: CoinTossVisual = null
	for child in game.hud.get_children():
		if child is CoinTossVisual:
			toss = child
	check(toss != null, "coin toss overlay appears when the match starts")
	check(toss != null and toss.mouse_filter == Control.MOUSE_FILTER_STOP, "coin toss blocks board input while spinning")
	var winner: int = game.current_player
	check(winner in [1, 2], "coin toss picks the first shooter")
	if toss != null:
		await toss.finished
		check(toss.caption.text == "%s 선공!" % AlkkagiPiece.STONE_NAMES[winner], "coin toss ends on the chosen side")
		check(game.current_player == winner, "first shooter does not change after the animation")
	if failures == 0:
		print("PASS test_coin_toss")
	quit()
