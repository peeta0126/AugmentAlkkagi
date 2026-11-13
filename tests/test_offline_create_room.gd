## 서버에 연결되지 않은 채 방 만들기를 누르면 빈 방장 화면이 아니라 이유와 함께 방 만들기·참가 화면에 머무는지 확인
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
	game.network_manager.gdsync_connected = false
	game._create_online_room()
	await process_frame
	check(game.screen_root is OnlineLobby, "lobby screen is shown")
	var lobby := game.screen_root as OnlineLobby
	check(lobby.join_panel.visible and not lobby.lobby_panel.visible, "stays on the create/join panel instead of an empty host lobby")
	check(lobby.status_label.text != "", "shows why the room could not be created")
	check(not game.online_mode, "does not enter online mode")
	if failures == 0:
		print("PASS: offline create-room stays on the join panel")
	quit(failures)
