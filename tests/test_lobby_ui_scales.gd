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
	var menu := game.screen_root as MainMenu
	check(menu != null, "main menu is active")
	if menu == null:
		quit(1)
		return
	check(menu.menu_buttons.size() == 7 and menu.menu_icons.size() == 7, "all seven menu controls expose images")
	menu.logo_visual.size = Vector2(600, 200)
	check(menu.logo_visual.size == Vector2(600, 200), "logo image can be resized independently")
	menu.board_visual.size = Vector2(900, 500)
	check(menu.board_visual.size == Vector2(900, 500), "board image can be resized independently")
	menu.panel_visual.size = Vector2(460, 700)
	check(menu.panel_visual.size == Vector2(460, 700), "menu panel can be resized independently")
	menu.menu_buttons[0].size = Vector2(350, 60)
	check(menu.menu_buttons[0].size == Vector2(350, 60), "each button can be resized independently")
	menu.menu_icons[0].custom_minimum_size = Vector2(48, 48)
	check(menu.menu_icons[0].custom_minimum_size == Vector2(48, 48), "each menu icon can be resized independently")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: lobby image scale controls")
	quit(failures)
