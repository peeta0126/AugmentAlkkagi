extends Node2D

const PieceSceneScript := preload("res://scripts/physics/piece.gd")
const BoardScript := preload("res://scripts/gameplay/board.gd")
const StateMachineScript := preload("res://scripts/core/game_state_machine.gd")
const AugmentManagerScript := preload("res://scripts/augments/augment_manager.gd")
const TemporaryWallScript := preload("res://scripts/gameplay/temporary_wall.gd")
const SkillProjectileScript := preload("res://scripts/gameplay/skill_projectile.gd")
const NetworkManagerScript := preload("res://scripts/network/network_manager.gd")

var state_machine: GameStateMachine
var augment_manager: AugmentManager
var board: AlkkagiBoard
var world: Node2D
var ui: CanvasLayer
var screen_root: Control
var hud: Control
var turn_label: Label
var count_label: Label
var hint_label: Label
var power_bar: ProgressBar
var selected_piece: AlkkagiPiece
var dragging := false
var aim_cancelled_until_left_release := false
var current_player := 1
var round_count := 0
var round_actions: Dictionary = {1: false, 2: false}
var starting_piece_count := GameplayRules.DEFAULT_PIECES
var settle_time := 0.0
var shot_elapsed := 0.0
var game_serial := 0
var selection_player := 1
var selection_is_initial := true
var selection_resume_player := 1
var selection_stage_id := 0
var selection_pending_players: Array[int] = []
var current_choices: Array[AugmentDefinition] = []
var active_skill: AugmentEffect
var active_skill_player := 0
var blizzard_turns := 0
var blizzard_damp_bonus := 0.0
var blizzard_speed_multiplier := 1.0
var blind_turns: Dictionary = {1: 0, 2: 0}
var temporary_walls: Array[TemporaryWall] = []
var network_manager: Node
var online_mode := false
var online_is_host := false
var local_player_id := 0
var network_skill_targets: Array[int] = []
var network_status_label: Label
var network_winner := 0
var network_wall_signature := ""
var next_wall_id := 1
var skill_targeting_snapshot_logged := false

func _skill_debug(message: String) -> void:
	if OS.is_debug_build():
		print("[active-skill] %s" % message)

func _ready() -> void:
	GDSync.connected.connect(_on_gdsync_connected)
	GDSync.connection_failed.connect(_on_gdsync_connection_failed)
	GDSync.disconnected.connect(_on_gdsync_disconnected)
	GDSync.start_multiplayer()
	state_machine = StateMachineScript.new()
	add_child(state_machine)
	augment_manager = AugmentManagerScript.new()
	add_child(augment_manager)
	network_manager = NetworkManagerScript.new()
	add_child(network_manager)
	network_manager.lobby_updated.connect(_on_network_lobby_updated)
	network_manager.connection_message.connect(_on_network_message)
	network_manager.session_ended.connect(_on_network_session_ended)
	world = Node2D.new()
	world.name = "GameWorld"
	add_child(world)
	ui = CanvasLayer.new()
	add_child(ui)
	show_main_menu()
	_start_debug_network_driver()

func _start_debug_network_driver() -> void:
	if not OS.is_debug_build():
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--gdsync-test-role="):
			var driver: Node = load("res://tests/gdsync_lobby_driver.gd").new()
			add_child(driver)
			return

func _on_gdsync_connected() -> void:
	print("GD-Sync 연결 성공")

func _on_gdsync_connection_failed(error: int) -> void:
	var reason := "UNKNOWN"
	if error >= 0 and error < ENUMS.CONNECTION_FAILED.size():
		reason = ENUMS.CONNECTION_FAILED.keys()[error]
	push_error("GD-Sync 연결 실패: %s (error=%d)" % [reason, error])

func _on_gdsync_disconnected() -> void:
	print("GD-Sync 연결 끊김")

func show_main_menu() -> void:
	if network_manager and network_manager.is_online():
		network_manager.shutdown(false)
	online_mode = false
	online_is_host = false
	local_player_id = 0
	clear_world()
	augment_manager.reset_match()
	reset_runtime_effects()
	state_machine.transition(GameStateMachine.State.MAIN_MENU)
	set_screen(_panel_root())
	_add_background(screen_root, Color("24160f"))
	var title := _label("증강 알까기", 58, Color("f4d79a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(340, 92)
	title.size = Vector2(600, 80)
	screen_root.add_child(title)
	var subtitle := _label("AUGMENT ALKKAGI", 21, Color("c89e65"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(340, 166)
	subtitle.size = Vector2(600, 40)
	screen_root.add_child(subtitle)
	var card := PanelContainer.new()
	card.position = Vector2(438, 210)
	card.size = Vector2(404, 410)
	card.add_theme_stylebox_override("panel", _style(Color("4a2d1f"), 16, Color("7b5134"), 2))
	screen_root.add_child(card)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 13)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 28)
	card.add_child(menu)
	menu.add_child(_button("로컬 대전 시작", _start_local_setup))
	menu.add_child(_button("온라인 방 만들기", _create_online_room))
	menu.add_child(_button("온라인 방 코드 참가", _show_online_join_room))
	menu.add_child(_button("LAN / Tailscale", _show_lan_menu))
	menu.add_child(_button("설정", _show_settings))
	menu.add_child(_button("게임 종료", get_tree().quit))
	var version := _label("Augment Phase · v0.2.0", 15, Color("a88869"))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.position = Vector2(440, 625)
	version.size = Vector2(400, 30)
	screen_root.add_child(version)

func _start_local_setup() -> void:
	state_machine.transition(GameStateMachine.State.LOCAL_SETUP)
	set_screen(_panel_root())
	_add_background(screen_root)
	var title := _label("로컬 대전 설정", 42, Color("f4d79a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(390, 110)
	title.size = Vector2(500, 60)
	screen_root.add_child(title)
	var info := _label("두 플레이어가 증강을 고른 뒤 번갈아 플레이합니다.", 20, Color("dac7ae"))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.position = Vector2(340, 180)
	info.size = Vector2(600, 35)
	screen_root.add_child(info)
	var picker := HBoxContainer.new()
	picker.position = Vector2(450, 280)
	picker.size = Vector2(380, 64)
	picker.alignment = BoxContainer.ALIGNMENT_CENTER
	picker.add_theme_constant_override("separation", 22)
	screen_root.add_child(picker)
	picker.add_child(_button("◀", func(): _change_piece_count(-1)))
	var value := _label("시작 바둑알: %d개" % starting_piece_count, 25, Color.WHITE)
	value.name = "PieceCount"
	value.custom_minimum_size = Vector2(220, 58)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	picker.add_child(value)
	picker.add_child(_button("▶", func(): _change_piece_count(1)))
	var start := _button("증강 선택 시작", begin_match)
	start.position = Vector2(490, 400)
	start.size = Vector2(300, 64)
	screen_root.add_child(start)
	var back := _button("뒤로", show_main_menu)
	back.position = Vector2(540, 492)
	back.size = Vector2(200, 54)
	screen_root.add_child(back)

func _change_piece_count(delta: int) -> void:
	starting_piece_count = GameplayRules.clamp_piece_count(starting_piece_count + delta)
	var value := screen_root.find_child("PieceCount", true, false) as Label
	if value:
		value.text = "시작 바둑알: %d개" % starting_piece_count

func _show_settings() -> void:
	state_machine.transition(GameStateMachine.State.PAUSED)
	set_screen(_panel_root())
	_add_background(screen_root)
	var title := _label("설정", 44, Color("f4d79a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(440, 120)
	title.size = Vector2(400, 60)
	screen_root.add_child(title)
	var fullscreen := CheckBox.new()
	fullscreen.text = "전체 화면"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.position = Vector2(440, 260)
	fullscreen.size = Vector2(430, 48)
	fullscreen.add_theme_font_size_override("font_size", 19)
	fullscreen.toggled.connect(_set_fullscreen)
	screen_root.add_child(fullscreen)
	var volume_text := _label("전체 음량", 19, Color("dac7ae"))
	volume_text.position = Vector2(440, 335)
	volume_text.size = Vector2(150, 35)
	screen_root.add_child(volume_text)
	var volume := HSlider.new()
	volume.position = Vector2(570, 333)
	volume.size = Vector2(270, 36)
	volume.min_value = 0
	volume.max_value = 100
	volume.value = db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0
	volume.value_changed.connect(_set_master_volume)
	screen_root.add_child(volume)
	var back := _button("완료", show_main_menu)
	back.position = Vector2(520, 430)
	back.size = Vector2(240, 58)
	screen_root.add_child(back)

func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)

func _set_master_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value / 100.0, 0.0001)))

func _create_online_room() -> void:
	var error: Error = network_manager.create_online_room()
	if error == OK:
		online_mode = true
		online_is_host = true
		local_player_id = 1
		_show_network_lobby()

func _show_online_join_room() -> void:
	state_machine.transition(GameStateMachine.State.JOIN_ROOM)
	set_screen(_panel_root())
	_add_background(screen_root)
	var title := _label("온라인 방 참가", 42, Color("f4d79a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(390, 100)
	title.size = Vector2(500, 60)
	screen_root.add_child(title)
	var guide := _label("친구에게 받은 6자리 방 코드를 입력하세요.", 19, Color("dac7ae"))
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.position = Vector2(300, 180)
	guide.size = Vector2(680, 35)
	screen_root.add_child(guide)
	var code := LineEdit.new()
	code.name = "RoomCode"
	code.placeholder_text = "000000"
	code.max_length = 6
	code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code.position = Vector2(490, 250)
	code.size = Vector2(300, 58)
	code.add_theme_font_size_override("font_size", 28)
	screen_root.add_child(code)
	network_status_label = _label("", 17, Color("e9c99a"))
	network_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	network_status_label.position = Vector2(300, 330)
	network_status_label.size = Vector2(680, 60)
	network_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen_root.add_child(network_status_label)
	var join := _button("참가", func(): _join_online_code(code.text))
	join.position = Vector2(490, 420)
	join.size = Vector2(300, 60)
	screen_root.add_child(join)
	var back := _button("뒤로", show_main_menu)
	back.position = Vector2(520, 505)
	back.size = Vector2(240, 54)
	screen_root.add_child(back)

func _join_online_code(code: String) -> void:
	var error: Error = network_manager.join_online_room(code)
	if error == OK:
		online_mode = true
		online_is_host = false
		local_player_id = 2

func _show_lan_menu() -> void:
	state_machine.transition(GameStateMachine.State.JOIN_ROOM)
	set_screen(_panel_root())
	_add_background(screen_root)
	var title := _label("LAN / Tailscale 대전", 42, Color("f4d79a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(340, 120)
	title.size = Vector2(600, 60)
	screen_root.add_child(title)
	var guide := _label("기존 UDP 직접 연결 방식을 사용합니다.", 18, Color("dac7ae"))
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.position = Vector2(300, 195)
	guide.size = Vector2(680, 35)
	screen_root.add_child(guide)
	var create := _button("LAN 방 만들기", _create_network_room)
	create.position = Vector2(490, 285)
	create.size = Vector2(300, 60)
	screen_root.add_child(create)
	var join := _button("IP 주소로 참가", _show_join_room)
	join.position = Vector2(490, 370)
	join.size = Vector2(300, 60)
	screen_root.add_child(join)
	var back := _button("뒤로", show_main_menu)
	back.position = Vector2(520, 475)
	back.size = Vector2(240, 54)
	screen_root.add_child(back)

func _create_network_room() -> void:
	var error: Error = network_manager.create_host()
	if error == OK:
		online_mode = true
		online_is_host = true
		local_player_id = 1
		_show_network_lobby()

func _show_join_room() -> void:
	state_machine.transition(GameStateMachine.State.JOIN_ROOM)
	set_screen(_panel_root())
	_add_background(screen_root)
	var title := _label("방 참가하기", 42, Color("f4d79a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(390, 90)
	title.size = Vector2(500, 60)
	screen_root.add_child(title)
	var guide := _label("호스트의 Tailscale IPv4 주소와 UDP 포트를 입력하세요.", 18, Color("dac7ae"))
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.position = Vector2(300, 165)
	guide.size = Vector2(680, 35)
	screen_root.add_child(guide)
	var address := LineEdit.new()
	address.name = "Address"
	address.placeholder_text = "예: 100.64.12.34 또는 127.0.0.1"
	address.text = "127.0.0.1"
	address.position = Vector2(390, 235)
	address.size = Vector2(360, 52)
	address.add_theme_font_size_override("font_size", 19)
	screen_root.add_child(address)
	var port := SpinBox.new()
	port.name = "Port"
	port.min_value = 1024
	port.max_value = 65535
	port.value = 7777
	port.position = Vector2(765, 235)
	port.size = Vector2(125, 52)
	screen_root.add_child(port)
	network_status_label = _label("", 17, Color("e9c99a"))
	network_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	network_status_label.position = Vector2(300, 310)
	network_status_label.size = Vector2(680, 60)
	network_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen_root.add_child(network_status_label)
	var join := _button("참가", func(): _join_network_address(address.text, int(port.value)))
	join.position = Vector2(490, 400)
	join.size = Vector2(300, 60)
	screen_root.add_child(join)
	var back := _button("뒤로", show_main_menu)
	back.position = Vector2(520, 485)
	back.size = Vector2(240, 54)
	screen_root.add_child(back)

func _join_network_address(address: String, port: int) -> void:
	var error: Error = network_manager.join_host(address.strip_edges(), port)
	if error == OK:
		online_mode = true
		online_is_host = false
		local_player_id = 2

func _show_network_lobby() -> void:
	state_machine.transition(GameStateMachine.State.LOBBY)
	set_screen(_panel_root())
	_add_background(screen_root)
	var room_suffix := " · 방 코드 %s" % network_manager.get_room_code() if network_manager.is_gdsync_mode() else ""
	var title := _label("네트워크 대전 로비%s" % room_suffix, 40, Color("f4d79a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(360, 45)
	title.size = Vector2(560, 60)
	screen_root.add_child(title)
	var role := "방장 · 흑돌" if online_is_host else "참가자 · 백돌"
	var role_label := _label(role, 22, AlkkagiPiece.OWNER_COLORS[local_player_id])
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.position = Vector2(420, 110)
	role_label.size = Vector2(440, 40)
	screen_root.add_child(role_label)
	var players := _label("", 20, Color("eee3cf"))
	players.name = "LobbyPlayers"
	players.position = Vector2(310, 180)
	players.size = Vector2(660, 110)
	players.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	players.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	screen_root.add_child(players)
	var settings := HBoxContainer.new()
	settings.position = Vector2(420, 315)
	settings.size = Vector2(440, 58)
	settings.alignment = BoxContainer.ALIGNMENT_CENTER
	settings.add_theme_constant_override("separation", 15)
	screen_root.add_child(settings)
	var left := _button("◀", func(): network_manager.set_piece_count(int(network_manager.get("piece_count")) - 1))
	left.custom_minimum_size = Vector2(62, 48)
	left.disabled = not online_is_host
	settings.add_child(left)
	var count := _label("", 22, Color.WHITE)
	count.name = "LobbyPieceCount"
	count.custom_minimum_size = Vector2(220, 48)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	settings.add_child(count)
	var right := _button("▶", func(): network_manager.set_piece_count(int(network_manager.get("piece_count")) + 1))
	right.custom_minimum_size = Vector2(62, 48)
	right.disabled = not online_is_host
	settings.add_child(right)
	var ready_button := CheckButton.new()
	ready_button.name = "ReadyButton"
	ready_button.text = "준비"
	ready_button.position = Vector2(470, 400)
	ready_button.size = Vector2(160, 54)
	ready_button.add_theme_font_size_override("font_size", 21)
	ready_button.toggled.connect(func(value: bool): network_manager.set_ready(value))
	screen_root.add_child(ready_button)
	var start := _button("게임 시작", func(): network_manager.start_match())
	start.name = "LobbyStart"
	start.position = Vector2(650, 400)
	start.size = Vector2(210, 54)
	start.visible = online_is_host
	screen_root.add_child(start)
	var transport_text := "GD-Sync 온라인 · 최대 2명" if network_manager.is_gdsync_mode() else "UDP 7777 · 최대 2명"
	network_status_label = _label(transport_text, 16, Color("c6aa85"))
	network_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	network_status_label.position = Vector2(340, 480)
	network_status_label.size = Vector2(600, 55)
	screen_root.add_child(network_status_label)
	var leave := _button("방 나가기", show_main_menu)
	leave.position = Vector2(520, 570)
	leave.size = Vector2(240, 54)
	screen_root.add_child(leave)
	_refresh_network_lobby()

func _refresh_network_lobby() -> void:
	if state_machine.current != GameStateMachine.State.LOBBY or screen_root == null:
		return
	var players := screen_root.find_child("LobbyPlayers", true, false) as Label
	if players:
		var ready_state: Dictionary = network_manager.get("ready_state")
		var connected_state: Dictionary = network_manager.get("connected_players")
		var guest_status := "준비" if bool(ready_state.get(2, false)) else "대기"
		if not bool(connected_state.get(2, false)):
			guest_status = "접속 대기"
		players.text = "방장  · 흑돌 · %s\n참가자 · 백돌 · %s" % ["준비" if bool(ready_state.get(1, false)) else "대기", guest_status]
	var count := screen_root.find_child("LobbyPieceCount", true, false) as Label
	if count:
		count.text = "시작 바둑알 %d개" % int(network_manager.get("piece_count"))
	var ready_button := screen_root.find_child("ReadyButton", true, false) as CheckButton
	if ready_button:
		var ready_state: Dictionary = network_manager.get("ready_state")
		ready_button.set_pressed_no_signal(bool(ready_state.get(local_player_id, false)))
	var start := screen_root.find_child("LobbyStart", true, false) as Button
	if start:
		start.disabled = not network_manager.can_start()

func _on_network_lobby_updated(_data: Dictionary) -> void:
	if not online_mode and network_manager.is_online():
		online_mode = true
		online_is_host = network_manager.is_host()
		local_player_id = int(network_manager.get("local_player_id"))
	if state_machine.current == GameStateMachine.State.JOIN_ROOM:
		_show_network_lobby()
	else:
		_refresh_network_lobby()

func _on_network_message(text: String, is_error: bool) -> void:
	if network_status_label and is_instance_valid(network_status_label):
		network_status_label.text = text
		network_status_label.modulate = Color("ff8d7b") if is_error else Color("e9c99a")

func _on_network_session_ended(reason: String) -> void:
	if online_is_host and network_manager.is_online():
		_show_network_lobby()
		_on_network_message(reason, true)
		return
	show_main_menu()
	var notice := _label(reason, 17, Color("ff9c8d"))
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.position = Vector2(300, 665)
	notice.size = Vector2(680, 35)
	screen_root.add_child(notice)

func begin_match() -> void:
	clear_world()
	augment_manager.reset_match()
	reset_runtime_effects()
	current_player = 1
	selection_stage_id += 1
	selection_pending_players = [1, 2]
	show_augment_selection(1, true, 1)

# 테스트 도구가 증강 선택 단계를 건너뛰어 물리 보드를 직접 만들 때 사용한다.
func start_game() -> void:
	clear_world()
	augment_manager.reset_match()
	reset_runtime_effects()
	start_game_world()

func show_augment_selection(player_id: int, initial: bool, resume_player: int) -> void:
	cancel_aim()
	selection_player = player_id
	selection_is_initial = initial
	selection_resume_player = resume_player
	current_choices = augment_manager.get_choices(player_id, 3)
	state_machine.transition(GameStateMachine.State.INITIAL_AUGMENT_SELECTION if initial else GameStateMachine.State.AUGMENT_SELECTION)
	set_screen(_panel_root())
	_add_background(screen_root, Color(0.055, 0.035, 0.025, 0.96))
	var color: Color = AlkkagiPiece.OWNER_COLORS[player_id]
	var player_name: String = str(AlkkagiPiece.STONE_NAMES[player_id])
	var title := _label("%s 플레이어 · 증강 선택" % player_name, 38, color.lightened(0.22))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(250, 48)
	title.size = Vector2(780, 58)
	screen_root.add_child(title)
	var subtitle_text := "게임 시작 증강을 하나 선택하세요" if initial else "%d라운드 완료 보상 — 양쪽 모두 선택해야 재개됩니다" % round_count
	var subtitle := _label(subtitle_text, 18, Color("ddccb0"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(300, 108)
	subtitle.size = Vector2(680, 35)
	screen_root.add_child(subtitle)
	var row := HBoxContainer.new()
	row.position = Vector2(118, 180)
	row.size = Vector2(1044, 380)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	screen_root.add_child(row)
	for definition in current_choices:
		row.add_child(_augment_card(definition))
	var footer := _label("선택 중에는 발사와 물리 진행이 잠깁니다", 16, Color("9f8a73"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.position = Vector2(340, 625)
	footer.size = Vector2(600, 28)
	screen_root.add_child(footer)
	screen_root.modulate.a = 0.0
	create_tween().tween_property(screen_root, "modulate:a", 1.0, 0.22)

func _augment_card(definition: AugmentDefinition) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(316, 360)
	card.text = "%s\n\n%s\n[%s]\n\n%s\n\n%s" % [definition.icon_text, definition.display_name, definition.rarity_name(), definition.description, definition.trigger_description]
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_theme_font_size_override("font_size", 19)
	card.add_theme_color_override("font_color", Color("f6ead5"))
	card.add_theme_color_override("font_hover_color", Color.WHITE)
	var rarity_color := definition.rarity_color()
	card.add_theme_stylebox_override("normal", _style(Color("39271e"), 15, rarity_color.darkened(0.28), 3))
	card.add_theme_stylebox_override("hover", _style(Color("59402e"), 15, rarity_color, 5))
	card.add_theme_stylebox_override("pressed", _style(Color("6b4b30"), 15, Color("ffe39a"), 5))
	card.tooltip_text = definition.description
	card.pressed.connect(_choose_augment.bind(definition.id))
	card.mouse_entered.connect(_animate_card.bind(card, Vector2(1.035, 1.035)))
	card.mouse_exited.connect(_animate_card.bind(card, Vector2.ONE))
	return card

func _animate_card(card: Control, target_scale: Vector2) -> void:
	card.pivot_offset = card.size * 0.5
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(card, "scale", target_scale, 0.12)

func _choose_augment(augment_id: StringName) -> void:
	if state_machine.current not in [GameStateMachine.State.INITIAL_AUGMENT_SELECTION, GameStateMachine.State.AUGMENT_SELECTION]:
		return
	var was_offered := false
	for definition in current_choices:
		if definition.id == augment_id:
			was_offered = true
			break
	if not was_offered:
		return
	if online_mode:
		network_manager.submit_augment_choice(augment_id)
		# Host submissions are processed synchronously. If this was the second
		# choice, the handler already started/resumed the game and must not be
		# covered by a stale waiting screen.
		if state_machine.current in [GameStateMachine.State.INITIAL_AUGMENT_SELECTION, GameStateMachine.State.AUGMENT_SELECTION]:
			network_show_waiting("상대 플레이어의 증강 선택을 기다리는 중…")
		return
	if not augment_manager.acquire(self, selection_player, augment_id):
		return
	selection_pending_players.erase(selection_player)
	if not selection_pending_players.is_empty():
		show_augment_selection(selection_pending_players[0], selection_is_initial, selection_resume_player)
	elif selection_is_initial:
		start_game_world()
	else:
		resume_after_augment_selection(selection_resume_player)

func start_game_world() -> void:
	clear_world()
	game_serial += 1
	current_player = 1
	settle_time = 0.0
	shot_elapsed = 0.0
	board = BoardScript.new()
	board.name = "Board"
	world.add_child(board)
	for owner_id in [1, 2]:
		var positions := GameplayRules.starting_positions(AlkkagiBoard.BOARD_RECT, owner_id, starting_piece_count)
		for index in positions.size():
			spawn_piece(owner_id, owner_id * 100 + index, positions[index])
	build_hud()
	state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
	update_hud("자신의 알을 잡아당겨 발사하세요")

func spawn_piece(owner_id: int, piece_id: int, spawn_position: Vector2) -> void:
	var piece := PieceSceneScript.new() as AlkkagiPiece
	piece.name = "Piece_%d" % piece_id
	piece.setup(owner_id, piece_id)
	piece.position = spawn_position
	piece.selected.connect(_on_piece_pressed)
	world.add_child(piece)
	if online_mode and not online_is_host:
		piece.freeze = true
	augment_manager.apply_owned_to_piece(owner_id, piece)
	if blizzard_turns > 0:
		piece.field_damp_bonus = blizzard_damp_bonus
		piece.field_speed_multiplier = blizzard_speed_multiplier
		piece.refresh_physics()

func build_hud() -> void:
	set_screen(_panel_root())
	hud = screen_root
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := ColorRect.new()
	top.color = Color(0.08, 0.045, 0.025, 0.91)
	top.position = Vector2.ZERO
	top.size = Vector2(1280, 84)
	hud.add_child(top)
	turn_label = _label("", 28, Color.WHITE)
	turn_label.position = Vector2(420, 12)
	turn_label.size = Vector2(440, 36)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(turn_label)
	count_label = _label("", 17, Color("e6d4ba"))
	count_label.position = Vector2(420, 49)
	count_label.size = Vector2(440, 28)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(count_label)
	_add_augment_hud(1, Vector2(18, 110))
	_add_augment_hud(2, Vector2(950, 110))
	hint_label = _label("", 16, Color("fff0c2"))
	hint_label.position = Vector2(20, 610)
	hint_label.size = Vector2(310, 72)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(hint_label)
	power_bar = ProgressBar.new()
	power_bar.position = Vector2(32, 570)
	power_bar.size = Vector2(270, 24)
	power_bar.max_value = 100
	power_bar.show_percentage = false
	hud.add_child(power_bar)
	var power_text := _label("POWER", 14, Color("dec8a6"))
	power_text.position = Vector2(32, 545)
	power_text.size = Vector2(100, 25)
	hud.add_child(power_text)
	var menu := _button("메뉴", show_main_menu)
	menu.position = Vector2(1090, 18)
	menu.size = Vector2(150, 48)
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(menu)
	_add_active_skill_hud()
	if int(blind_turns[current_player]) > 0 and (not online_mode or current_player == local_player_id):
		_add_blind_overlay()

func _add_augment_hud(player_id: int, hud_position: Vector2) -> void:
	var panel := PanelContainer.new()
	panel.position = hud_position
	panel.size = Vector2(312, 190)
	panel.add_theme_stylebox_override("panel", _style(Color(0.12, 0.07, 0.045, 0.84), 10, AlkkagiPiece.OWNER_COLORS[player_id].darkened(0.12), 2))
	hud.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	panel.add_child(box)
	var player_name: String = str(AlkkagiPiece.STONE_NAMES[player_id])
	box.add_child(_label("%s 플레이어 증강" % player_name, 18, AlkkagiPiece.OWNER_COLORS[player_id].lightened(0.24)))
	for definition: AugmentDefinition in augment_manager.owned[player_id]:
		var item := _label("%s  %s" % [definition.icon_text, definition.display_name], 16, definition.rarity_color())
		item.tooltip_text = definition.description
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		box.add_child(item)
	if augment_manager.owned[player_id].is_empty():
		box.add_child(_label("보유 증강 없음", 15, Color("9a8b79")))
	var owned_count: int = augment_manager.owned[player_id].size()
	var progress_text := "증강 획득 완료" if owned_count >= GameplayRules.MAX_AUGMENTS_PER_PLAYER else "증강 %d / %d" % [owned_count, GameplayRules.MAX_AUGMENTS_PER_PLAYER]
	box.add_child(_label(progress_text, 15, Color("d9c59f")))

func _add_active_skill_hud() -> void:
	if online_mode and current_player != local_player_id:
		_skill_debug("HUD skipped: current_player=%d local_player=%d state=%s" % [current_player, local_player_id, GameStateMachine.State.keys()[state_machine.current]])
		return
	var actives := augment_manager.active_effects(current_player)
	if actives.is_empty():
		return
	_skill_debug("HUD built: current_player=%d local_player=%d state=%s active_count=%d" % [current_player, local_player_id, GameStateMachine.State.keys()[state_machine.current], actives.size()])
	var box := VBoxContainer.new()
	box.position = Vector2(950, 330)
	box.size = Vector2(300, 220)
	box.add_theme_constant_override("separation", 6)
	hud.add_child(box)
	box.add_child(_label("액티브 스킬", 17, Color("f1d49a")))
	for effect in actives:
		var button := _button("%s · %s" % [effect.definition.display_name, effect.status_text()], _activate_skill.bind(effect))
		button.custom_minimum_size = Vector2(290, 42)
		button.disabled = not effect.can_activate(self, current_player)
		button.tooltip_text = effect.definition.description
		box.add_child(button)

func _add_blind_overlay() -> void:
	var veil := ColorRect.new()
	veil.color = Color(0.01, 0.008, 0.006, 0.68)
	veil.position = AlkkagiBoard.BOARD_RECT.position
	veil.size = AlkkagiBoard.BOARD_RECT.size
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(veil)
	var warning := _label("시야 제한", 22, Color(1, 1, 1, 0.72))
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.position = Vector2(veil.position.x, veil.position.y + 18)
	warning.size = Vector2(veil.size.x, 35)
	hud.add_child(warning)

func _activate_skill(effect: AugmentEffect) -> void:
	var can_use := effect.can_activate(self, current_player)
	_skill_debug("button pressed: augment=%s current_player=%d local_player=%d state=%s can_activate=%s" % [effect.definition.id, current_player, local_player_id, GameStateMachine.State.keys()[state_machine.current], can_use])
	if not state_machine.allows_aiming():
		_skill_debug("activation rejected locally: state does not allow aiming")
		return
	if not can_use:
		_skill_debug("activation rejected locally: can_activate=false")
		return
	if online_mode and current_player != local_player_id:
		_skill_debug("activation rejected locally: not the local player's turn")
		return
	if online_mode and not online_is_host:
		if current_player != local_player_id:
			return
		if effect.definition.target_mode == AugmentDefinition.TargetMode.NONE:
			var target_ids: Array[int] = []
			network_manager.submit_active_skill(effect.definition.id, target_ids)
			network_show_waiting("스킬 요청을 호스트가 검증하는 중…")
		else:
			begin_skill_targeting(effect, current_player)
			network_skill_targets.clear()
		return
	effect.begin_active(self, current_player)

func begin_skill_targeting(effect: AugmentEffect, player_id: int) -> void:
	cancel_aim()
	active_skill = effect
	active_skill_player = player_id
	state_machine.transition(GameStateMachine.State.SKILL_TARGETING)
	skill_targeting_snapshot_logged = false
	_skill_debug("entered SKILL_TARGETING: augment=%s player=%d" % [effect.definition.id, player_id])
	set_skill_hint("%s: 대상을 선택하세요. 우클릭으로 취소" % effect.definition.display_name)

func cancel_active_skill() -> void:
	if active_skill:
		active_skill.cancel_active()
	active_skill = null
	active_skill_player = 0
	skill_targeting_snapshot_logged = false
	state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
	update_hud("자신의 돌을 잡아당겨 발사하세요")

func finish_active_skill(player_id: int, consumes_turn: bool) -> void:
	active_skill = null
	active_skill_player = 0
	if consumes_turn:
		settle_time = 0.0
		shot_elapsed = 0.0
		state_machine.transition(GameStateMachine.State.PIECES_MOVING)
		update_hud("스킬 효과가 끝날 때까지 기다리는 중…")
	else:
		state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
		build_hud()
		update_hud("자신의 돌을 잡아당겨 발사하세요")

func set_skill_hint(text: String) -> void:
	if hint_label:
		hint_label.text = text

func _current_shot_profile() -> Dictionary:
	return augment_manager.shot_profile(current_player)

func _on_piece_pressed(piece: AlkkagiPiece) -> void:
	if state_machine.current == GameStateMachine.State.SKILL_TARGETING and active_skill:
		_skill_debug("piece target clicked: augment=%s piece=%d owner=%d" % [active_skill.definition.id, piece.piece_id, piece.owner_id])
		if online_mode and not online_is_host:
			_network_collect_skill_target(piece)
			return
		active_skill.on_piece_target(self, active_skill_player, piece)
		return
	if aim_cancelled_until_left_release or not state_machine.allows_aiming() or piece.owner_id != current_player:
		return
	if online_mode and current_player != local_player_id:
		return
	if selected_piece:
		selected_piece.set_selected(false)
	selected_piece = piece
	selected_piece.set_selected(true)
	dragging = true
	update_aim(get_global_mouse_position())
	update_hud("ESC / 우클릭: 발사 취소")

func update_aim(pointer: Vector2) -> void:
	if selected_piece == null:
		return
	pointer = augment_manager.adjust_pointer(self, current_player, selected_piece, pointer)
	var profile := _current_shot_profile()
	var max_drag := GameplayRules.BALANCE.drag_distance * float(profile.max_drag_multiplier)
	var empowered := not is_equal_approx(float(profile.max_drag_multiplier), 1.0) or not is_equal_approx(float(profile.impulse_multiplier), 1.0)
	board.set_aim(selected_piece.global_position, pointer, AlkkagiPiece.OWNER_COLORS[current_player], max_drag, float(profile.guide_multiplier), empowered)
	if power_bar:
		power_bar.value = minf(100.0, selected_piece.global_position.distance_to(pointer) / max_drag * 100.0)

func _unhandled_input(event: InputEvent) -> void:
	if state_machine != null and state_machine.current == GameStateMachine.State.SKILL_TARGETING:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				cancel_active_skill()
			elif event.button_index == MOUSE_BUTTON_LEFT and active_skill and active_skill.definition.target_mode == AugmentDefinition.TargetMode.BOARD_POSITION:
				confirm_board_position_skill(get_global_mouse_position())
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if aim_cancelled_until_left_release:
			aim_cancelled_until_left_release = false
			get_viewport().set_input_as_handled()
			return
	if dragging and state_machine.allows_aiming():
		var cancel_requested: bool = false
		if event is InputEventKey:
			var key_event := event as InputEventKey
			cancel_requested = key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
		elif event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			cancel_requested = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT
		if cancel_requested:
			aim_cancelled_until_left_release = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			cancel_aim()
			update_hud("발사가 취소되었습니다. 턴은 유지됩니다.")
			get_viewport().set_input_as_handled()
			return
	if not dragging or selected_piece == null or not state_machine.allows_aiming():
		return
	if event is InputEventMouseMotion:
		update_aim(get_global_mouse_position())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		fire_selected(get_global_mouse_position())

func confirm_board_position_skill(board_position: Vector2) -> void:
	if state_machine.current != GameStateMachine.State.SKILL_TARGETING or active_skill == null or active_skill.definition.target_mode != AugmentDefinition.TargetMode.BOARD_POSITION:
		return
	if online_mode and not online_is_host:
		var target_ids: Array[int] = []
		_skill_debug("board target submitted: augment=%s position=%s" % [active_skill.definition.id, board_position])
		network_manager.submit_active_skill(active_skill.definition.id, target_ids, board_position)
		network_show_waiting("벽 설치 요청을 호스트가 검증하는 중…")
	else:
		active_skill.on_position_target(self, active_skill_player, board_position)

func fire_selected(pointer: Vector2) -> void:
	if not state_machine.allows_aiming() or selected_piece == null or not is_instance_valid(selected_piece):
		cancel_aim()
		return
	pointer = augment_manager.adjust_pointer(self, current_player, selected_piece, pointer)
	var profile := _current_shot_profile()
	var max_drag := GameplayRules.BALANCE.drag_distance * float(profile.max_drag_multiplier)
	var impulse := GameplayRules.shot_impulse(selected_piece.global_position, pointer, max_drag, float(profile.impulse_multiplier))
	if selected_piece.global_position.distance_to(pointer) < GameplayRules.MIN_SHOT_DRAG_DISTANCE:
		cancel_aim()
		update_hud("조금 더 길게 드래그하세요")
		return
	if online_mode and not online_is_host:
		var requested_piece_id := selected_piece.piece_id
		var pull_vector := GameplayRules.clamp_outgoing_pull_vector(selected_piece.global_position - pointer, max_drag)
		cancel_aim()
		network_manager.submit_shot(requested_piece_id, pull_vector)
		state_machine.transition(GameStateMachine.State.PIECES_MOVING)
		update_hud("발사 요청을 호스트가 검증하는 중…")
		return
	selected_piece.prepare_shot_speed_cap(GameplayRules.BALANCE.max_speed * float(profile.speed_multiplier))
	augment_manager.before_shot(current_player, selected_piece)
	augment_manager.notify_opponent_shot(self, current_player, selected_piece, impulse)
	selected_piece.set_selected(false)
	selected_piece.sleeping = false
	var transformed := augment_manager.transform_shot(self, current_player, selected_piece, impulse)
	if not transformed:
		selected_piece.apply_central_impulse(impulse)
	selected_piece = null
	dragging = false
	board.clear_aim()
	power_bar.value = 0
	settle_time = 0.0
	shot_elapsed = 0.0
	state_machine.transition(GameStateMachine.State.PIECES_MOVING)
	update_hud("알이 멈출 때까지 기다리는 중…")

func cancel_aim() -> void:
	if selected_piece and is_instance_valid(selected_piece):
		selected_piece.set_selected(false)
	selected_piece = null
	dragging = false
	if board:
		board.clear_aim()
	if power_bar:
		power_bar.value = 0

func _physics_process(delta: float) -> void:
	if state_machine == null or state_machine.current not in [GameStateMachine.State.PLAYER_AIMING, GameStateMachine.State.PIECES_MOVING]:
		return
	if online_mode and not online_is_host:
		return
	augment_manager.physics_tick(self, delta)
	remove_out_of_bounds()
	if state_machine.current != GameStateMachine.State.PIECES_MOVING:
		return
	shot_elapsed += delta
	var all_still := true
	for piece in get_pieces():
		if piece.linear_velocity.length() > GameplayRules.BALANCE.stop_threshold:
			all_still = false
			break
	settle_time = settle_time + delta if all_still and shot_elapsed > 0.35 else 0.0
	if settle_time >= 0.45:
		resolve_turn()

func remove_out_of_bounds() -> void:
	for piece in get_pieces():
		if not piece.invulnerable and not AlkkagiBoard.BOARD_RECT.grow(piece.visual_radius * 0.35).has_point(piece.global_position):
			piece.queue_free()

func resolve_turn() -> void:
	# Only the host/offline physics resolution may complete an action. This also
	# makes duplicate callbacks/RPC-driven attempts idempotent.
	if state_machine.current != GameStateMachine.State.PIECES_MOVING:
		return
	state_machine.transition(GameStateMachine.State.TURN_RESOLUTION)
	for piece in get_pieces():
		piece.stop_motion()
		piece.tick_status(current_player)
	tick_field_effects()
	var special_winner := augment_manager.check_special_victory(self)
	if special_winner != 0:
		show_game_over(special_winner)
		return
	var red_count := count_owner(1)
	var blue_count := count_owner(2)
	if red_count == 0 or blue_count == 0:
		show_game_over(2 if red_count == 0 else 1)
		return
	var completed_player := current_player
	var next_player := 2 if current_player == 1 else 1
	augment_manager.finish_turn(self, completed_player)
	round_actions[completed_player] = true
	if bool(round_actions[1]) and bool(round_actions[2]):
		round_count += 1
		round_actions = {1: false, 2: false}
		if round_count % GameplayRules.AUGMENT_ROUND_INTERVAL == 0 and _both_players_can_acquire():
			current_player = next_player
			if online_mode and online_is_host:
				network_manager.host_begin_round_selection(next_player, round_count)
				return
			begin_local_round_selection(next_player)
			return
	current_player = next_player
	build_hud()
	state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
	update_hud("자신의 알을 잡아당겨 발사하세요")

func reset_runtime_effects() -> void:
	active_skill = null
	active_skill_player = 0
	blizzard_turns = 0
	blizzard_damp_bonus = 0.0
	blizzard_speed_multiplier = 1.0
	blind_turns = {1: 0, 2: 0}
	temporary_walls.clear()
	network_wall_signature = ""
	round_count = 0
	round_actions = {1: false, 2: false}
	selection_pending_players.clear()
	aim_cancelled_until_left_release = false
	next_wall_id = 1

func _both_players_can_acquire() -> bool:
	return augment_manager.can_acquire(1) and augment_manager.can_acquire(2)

func begin_local_round_selection(resume_player: int) -> void:
	selection_stage_id += 1
	selection_pending_players.clear()
	for player_id in [1, 2]:
		if augment_manager.can_acquire(player_id):
			selection_pending_players.append(player_id)
	if selection_pending_players.is_empty():
		resume_after_augment_selection(resume_player)
		return
	show_augment_selection(selection_pending_players[0], false, resume_player)

func resume_after_augment_selection(resume_player: int) -> void:
	current_player = resume_player
	build_hud()
	state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
	update_hud("자신의 알을 잡아당겨 발사하세요")

func player_center(player_id: int) -> Vector2:
	var positions: Array[Vector2] = []
	for piece in get_pieces():
		if piece.owner_id == player_id:
			positions.append(piece.position)
	if positions.is_empty():
		return AlkkagiBoard.BOARD_RECT.get_center()
	var total := Vector2.ZERO
	for position in positions:
		total += position
	return total / positions.size()

func animate_projectile(from: Vector2, to: Vector2, color: Color, size: float = 6.0, broadcast: bool = true) -> void:
	var projectile: Area2D = SkillProjectileScript.new()
	world.add_child(projectile)
	projectile.setup(from, to, color, 0.24, size)
	if broadcast and online_mode and online_is_host:
		network_manager.broadcast_projectile(from, to, color, size)

func split_piece_and_launch(original: AlkkagiPiece, player_id: int, impulse: Vector2, spread_degrees: float) -> void:
	var origin := original.position
	world.remove_child(original)
	original.queue_free()
	for index in 3:
		var angle := deg_to_rad((index - 1) * spread_degrees)
		var direction := impulse.normalized().rotated(angle)
		var fragment_spacing := original.visual_radius * 0.62 * 2.25
		var perpendicular := direction.orthogonal() * float(index - 1) * fragment_spacing
		var piece_id := game_serial * 100000 + augment_manager.rng.randi_range(1000, 99999)
		spawn_piece(player_id, piece_id, origin + perpendicular)
		var fragment := world.get_node("Piece_%d" % piece_id) as AlkkagiPiece
		fragment.set_fragment()
		fragment.prepare_shot_speed_cap(original.speed_cap)
		augment_manager.before_shot(player_id, fragment)
		fragment.sleeping = false
		fragment.apply_central_impulse(direction * impulse.length() * 0.70)
	board.add_effect_line(origin - Vector2(24, 0), origin + Vector2(24, 0), Color("fff1ad"), 0.5, 5.0)

func try_dodge(player_id: int, ray_origin: Vector2, direction: Vector2, chance: float, distance: float) -> bool:
	var best: AlkkagiPiece
	var best_forward := INF
	for piece in get_pieces():
		if piece.owner_id != player_id or piece.status_kind == "stasis":
			continue
		var offset := piece.position - ray_origin
		var forward := offset.dot(direction)
		var side_distance := absf(offset.cross(direction))
		if forward > 0.0 and forward < 330.0 and side_distance < piece.visual_radius * 2.4 and forward < best_forward:
			best = piece
			best_forward = forward
	if best == null or augment_manager.rng.randf() > chance:
		return false
	var side := direction.orthogonal() * (1.0 if augment_manager.rng.randi() % 2 == 0 else -1.0)
	var destination := best.position + side * distance
	if not AlkkagiBoard.BOARD_RECT.grow(-best.visual_radius).has_point(destination):
		return false
	board.add_effect_line(best.position, destination, Color("75e7ff"), 0.45, 4.0)
	best.position = destination
	return true

func check_connect_four(player_id: int, tolerance: float) -> bool:
	var occupied := {}
	var spacing := AlkkagiBoard.GRID_RECT.size / float(AlkkagiBoard.GRID_COUNT - 1)
	for piece in get_pieces():
		if piece.owner_id != player_id:
			continue
		var local := piece.position - AlkkagiBoard.GRID_RECT.position
		var cell := Vector2i(roundi(local.x / spacing.x), roundi(local.y / spacing.y))
		if cell.x < 0 or cell.x >= 19 or cell.y < 0 or cell.y >= 19:
			continue
		if piece.position.distance_to(board.grid_point(cell.x, cell.y)) <= tolerance:
			occupied[cell] = true
	for cell: Vector2i in occupied:
		for direction in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
			var complete := true
			for step in 4:
				if not occupied.has(cell + direction * step):
					complete = false
					break
			if complete:
				return true
	return false

func swap_all_owners() -> void:
	for piece in get_pieces():
		piece.change_player_owner(2 if piece.owner_id == 1 else 1)
	board.add_effect_line(AlkkagiBoard.BOARD_RECT.position, AlkkagiBoard.BOARD_RECT.end, Color("d48cff"), 0.9, 7.0)

func run_train_event(knockback: float) -> void:
	var horizontal := augment_manager.rng.randi() % 2 == 0
	var ratio := augment_manager.rng.randf_range(0.25, 0.75)
	var from := Vector2(AlkkagiBoard.BOARD_RECT.position.x, AlkkagiBoard.BOARD_RECT.position.y + AlkkagiBoard.BOARD_RECT.size.y * ratio)
	var to := Vector2(AlkkagiBoard.BOARD_RECT.end.x, from.y)
	var direction := Vector2.RIGHT
	if not horizontal:
		from = Vector2(AlkkagiBoard.BOARD_RECT.position.x + AlkkagiBoard.BOARD_RECT.size.x * ratio, AlkkagiBoard.BOARD_RECT.position.y)
		to = Vector2(from.x, AlkkagiBoard.BOARD_RECT.end.y)
		direction = Vector2.DOWN
	board.add_effect_line(from, to, Color("ffcf55"), 1.25, 18.0)
	for piece in get_pieces():
		var distance_to_path := absf(piece.position.y - from.y) if horizontal else absf(piece.position.x - from.x)
		if distance_to_path < 35.0:
			piece.sleeping = false
			piece.apply_central_impulse(direction * knockback)

func start_blizzard(turns: int, damp_bonus: float, speed_multiplier: float) -> void:
	blizzard_turns = maxi(blizzard_turns, turns)
	blizzard_damp_bonus = damp_bonus
	blizzard_speed_multiplier = speed_multiplier
	board.set_blizzard(true)
	for piece in get_pieces():
		piece.field_damp_bonus = damp_bonus
		piece.field_speed_multiplier = speed_multiplier
		piece.refresh_physics()

func apply_blind(player_id: int, turns: int) -> void:
	blind_turns[player_id] = maxi(int(blind_turns[player_id]), turns)

func tick_field_effects() -> void:
	if blizzard_turns > 0:
		blizzard_turns -= 1
		if blizzard_turns == 0:
			board.set_blizzard(false)
			for piece in get_pieces():
				piece.field_damp_bonus = 0.0
				piece.field_speed_multiplier = 1.0
				piece.refresh_physics()
	if int(blind_turns[current_player]) > 0:
		blind_turns[current_player] = int(blind_turns[current_player]) - 1
	for wall in temporary_walls.duplicate():
		if not is_instance_valid(wall) or wall.tick():
			temporary_walls.erase(wall)
			if is_instance_valid(wall):
				wall.queue_free()

func position_overlaps_piece(position: Vector2, radius: float) -> bool:
	for piece in get_pieces():
		if piece.position.distance_to(position) < radius + piece.visual_radius:
			return true
	return false

func can_place_wall(position: Vector2, wall_rotation: float) -> bool:
	var half_size := GameplayRules.WALL_SIZE * 0.5
	for corner in [Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y), Vector2(half_size.x, half_size.y), Vector2(-half_size.x, half_size.y)]:
		if not AlkkagiBoard.BOARD_RECT.grow(-4.0).has_point(position + corner.rotated(wall_rotation)):
			return false
	for piece in get_pieces():
		var local_position := (piece.position - position).rotated(-wall_rotation)
		var closest := Vector2(clampf(local_position.x, -half_size.x, half_size.x), clampf(local_position.y, -half_size.y, half_size.y))
		if local_position.distance_to(closest) < piece.visual_radius + 4.0:
			return false
	return true

func spawn_wall(position: Vector2, duration: int, wall_rotation: float = 0.0) -> bool:
	if not can_place_wall(position, wall_rotation):
		return false
	var wall := TemporaryWallScript.new() as TemporaryWall
	world.add_child(wall)
	wall.setup(position, wall_rotation, duration, next_wall_id)
	next_wall_id += 1
	temporary_walls.append(wall)
	return true

func show_game_over(winner: int) -> void:
	network_winner = winner
	state_machine.transition(GameStateMachine.State.GAME_OVER)
	update_hud("")
	var overlay := ColorRect.new()
	overlay.color = Color(0.04, 0.025, 0.018, 0.78)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(overlay)
	var label := _label("%s 승리!" % AlkkagiPiece.STONE_NAMES[winner], 46, AlkkagiPiece.OWNER_COLORS[winner].lightened(0.12))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(340, 220)
	label.size = Vector2(600, 80)
	overlay.add_child(label)
	var replay_callback := begin_match
	var replay_text := "다시 하기"
	if online_mode:
		replay_text = "로비로" if online_is_host else "호스트를 기다리는 중"
		replay_callback = network_manager.return_to_lobby if online_is_host else Callable()
	var replay := _button(replay_text, replay_callback)
	replay.disabled = online_mode and not online_is_host
	replay.position = Vector2(490, 345)
	replay.size = Vector2(300, 62)
	overlay.add_child(replay)
	var menu := _button("메인 메뉴", show_main_menu)
	menu.position = Vector2(520, 430)
	menu.size = Vector2(240, 54)
	overlay.add_child(menu)

func get_pieces() -> Array[AlkkagiPiece]:
	var result: Array[AlkkagiPiece] = []
	for child in world.get_children():
		if child is AlkkagiPiece and not child.is_queued_for_deletion():
			result.append(child)
	return result

func count_owner(owner_id: int) -> int:
	var count := 0
	for piece in get_pieces():
		if piece.owner_id == owner_id:
			count += 1
	return count

# 온라인 대전에서는 호스트만 아래 명령을 실행하고 클라이언트는 결과 스냅샷만 표시한다.
func network_prepare_match(is_host_value: bool, player_id: int, count: int) -> void:
	online_mode = true
	online_is_host = is_host_value
	local_player_id = player_id
	starting_piece_count = GameplayRules.clamp_piece_count(count)
	network_winner = 0
	clear_world()
	augment_manager.reset_match()
	reset_runtime_effects()
	current_player = 1

func network_receive_offer(player_id: int, ids: Array[String], initial: bool, resume_player: int, stage: int, completed_round: int) -> void:
	# A new initial selection stage is also the network rematch reset boundary.
	if initial and selection_stage_id != stage:
		network_prepare_match(network_manager.is_host(), int(network_manager.get("local_player_id")), int(network_manager.get("piece_count")))
	selection_player = player_id
	selection_is_initial = initial
	selection_resume_player = resume_player
	selection_stage_id = stage
	if not initial:
		round_count = completed_round
	current_choices.clear()
	for augment_id in ids:
		var definition: AugmentDefinition = augment_manager.get_definition(StringName(augment_id))
		if definition:
			current_choices.append(definition)
	state_machine.transition(GameStateMachine.State.INITIAL_AUGMENT_SELECTION if initial else GameStateMachine.State.AUGMENT_SELECTION)
	show_augment_selection_from_choices()

func show_augment_selection_from_choices() -> void:
	var preserved := current_choices.duplicate()
	show_augment_selection(selection_player, selection_is_initial, selection_resume_player)
	current_choices = preserved
	var row := screen_root.get_child(screen_root.get_child_count() - 2) as HBoxContainer
	if row:
		for child in row.get_children():
			child.queue_free()
		for definition in current_choices:
			row.add_child(_augment_card(definition))

func network_show_waiting(message: String) -> void:
	cancel_aim()
	set_screen(_panel_root())
	_add_background(screen_root, Color(0.055, 0.035, 0.025, 0.96))
	var label := _label(message, 28, Color("f4d79a"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(260, 260)
	label.size = Vector2(760, 150)
	screen_root.add_child(label)

func network_augment_granted(player_id: int, _augment_id: StringName) -> void:
	if player_id == local_player_id:
		network_show_waiting("상대 플레이어의 증강 선택을 기다리는 중…")

func network_start_world(count: int) -> void:
	starting_piece_count = GameplayRules.clamp_piece_count(count)
	network_winner = 0
	start_game_world()
	if not online_is_host:
		for piece in get_pieces():
			piece.freeze = true

func network_selection_complete(stage: int, resume_player: int, completed_round: int) -> void:
	if stage != selection_stage_id or state_machine.current != GameStateMachine.State.AUGMENT_SELECTION:
		return
	round_count = completed_round
	resume_after_augment_selection(resume_player)

func find_piece(piece_id: int) -> AlkkagiPiece:
	for piece in get_pieces():
		if piece.piece_id == piece_id:
			return piece
	return null

func network_execute_shot(player_id: int, piece_id: int, pull_vector: Vector2) -> void:
	if not online_is_host or state_machine.current != GameStateMachine.State.PLAYER_AIMING or current_player != player_id:
		return
	var piece := find_piece(piece_id)
	if piece == null or piece.owner_id != player_id or piece.freeze:
		return
	var profile := augment_manager.shot_profile(player_id)
	var max_drag := GameplayRules.BALANCE.drag_distance * float(profile.max_drag_multiplier)
	if not GameplayRules.is_network_pull_vector_valid(pull_vector, max_drag):
		return
	selected_piece = piece
	selected_piece.set_selected(true)
	dragging = true
	fire_selected(piece.global_position - pull_vector)

func _network_collect_skill_target(piece: AlkkagiPiece) -> void:
	if active_skill == null or piece.piece_id in network_skill_targets:
		return
	var target_mode := active_skill.definition.target_mode
	var target_index := network_skill_targets.size()
	if active_skill.definition.id == &"wizard":
		if (target_index == 0 and piece.owner_id != local_player_id) or (target_index == 1 and piece.owner_id == local_player_id):
			return
	elif target_mode == AugmentDefinition.TargetMode.OWN_PIECE and piece.owner_id != local_player_id:
		return
	if target_mode == AugmentDefinition.TargetMode.ENEMY_PIECE and piece.owner_id == local_player_id:
		return
	network_skill_targets.append(piece.piece_id)
	var required := 2 if active_skill.definition.id in [&"piggyback", &"lantern", &"wizard"] else 1
	if network_skill_targets.size() >= required:
		network_manager.submit_active_skill(active_skill.definition.id, network_skill_targets)
		network_show_waiting("스킬 요청을 호스트가 검증하는 중…")

func create_network_snapshot() -> Dictionary:
	var piece_states := PackedFloat32Array()
	for piece in get_pieces():
		piece_states.append_array(piece.compact_network_state())
	var wall_states := PackedFloat32Array()
	for wall in temporary_walls:
		if is_instance_valid(wall):
			wall_states.append_array(PackedFloat32Array([wall.wall_id, wall.position.x, wall.position.y, wall.rotation, wall.turns_left]))
	var effect_states := {1: [], 2: []}
	for player_id in [1, 2]:
		for effect: AugmentEffect in augment_manager.effects[player_id]:
			effect_states[player_id].append({"id": str(effect.definition.id), "uses": effect.uses_left, "cooldown": effect.cooldown_left})
	return {
		"state": int(state_machine.current),
		"current_player": current_player,
		"winner": network_winner,
		"pieces": piece_states,
		"walls": wall_states,
		"blizzard": blizzard_turns,
		"blind": blind_turns.duplicate(),
		"round": round_count,
		"round_flags": (1 if bool(round_actions[1]) else 0) | (2 if bool(round_actions[2]) else 0),
		"effects": effect_states
	}

func apply_network_snapshot(snapshot: Dictionary, interpolation_duration: float = 0.05) -> void:
	if online_is_host or board == null:
		return
	var seen := {}
	var piece_states: PackedFloat32Array = snapshot.get("pieces", PackedFloat32Array())
	for offset in range(0, piece_states.size(), 17):
		if offset + 16 >= piece_states.size():
			break
		var piece_id := int(piece_states[offset])
		seen[piece_id] = true
		var piece := find_piece(piece_id)
		if piece == null:
			spawn_piece(int(piece_states[offset + 1]), piece_id, Vector2(piece_states[offset + 2], piece_states[offset + 3]))
			piece = find_piece(piece_id)
		piece.apply_compact_network_state(piece_states, offset, true, interpolation_duration)
	for piece in get_pieces():
		if not seen.has(piece.piece_id):
			piece.queue_free()
	var previous_player := current_player
	current_player = int(snapshot.get("current_player", current_player))
	round_count = int(snapshot.get("round", round_count))
	var round_flags := int(snapshot.get("round_flags", 0))
	round_actions = {1: (round_flags & 1) != 0, 2: (round_flags & 2) != 0}
	blind_turns = snapshot.get("blind", blind_turns)
	blizzard_turns = int(snapshot.get("blizzard", 0))
	board.set_blizzard(blizzard_turns > 0)
	_apply_network_effect_runtime(snapshot.get("effects", {}))
	_sync_network_walls(snapshot.get("walls", PackedFloat32Array()))
	var winner := int(snapshot.get("winner", 0))
	if winner != 0 and network_winner == 0:
		show_game_over(winner)
		return
	# A late movement snapshot must never close a reliable augment-selection UI.
	if state_machine.current in [GameStateMachine.State.INITIAL_AUGMENT_SELECTION, GameStateMachine.State.AUGMENT_SELECTION]:
		return
	var remote_state := int(snapshot.get("state", GameStateMachine.State.PLAYER_AIMING))
	# Target selection is client-local until an active-skill request reaches the
	# host. The host legitimately remains in PLAYER_AIMING during that interval.
	if state_machine.current == GameStateMachine.State.SKILL_TARGETING and current_player == local_player_id and remote_state == GameStateMachine.State.PLAYER_AIMING:
		if not skill_targeting_snapshot_logged:
			_skill_debug("kept local SKILL_TARGETING while host snapshot is PLAYER_AIMING")
			skill_targeting_snapshot_logged = true
		return
	skill_targeting_snapshot_logged = false
	if remote_state in [GameStateMachine.State.PLAYER_AIMING, GameStateMachine.State.PIECES_MOVING]:
		state_machine.transition(remote_state as GameStateMachine.State)
	if previous_player != current_player or turn_label == null:
		build_hud()
	update_hud("자신의 차례입니다" if current_player == local_player_id else "상대 차례를 기다리는 중…")

func network_active_skill_rejected(reason: String) -> void:
	_skill_debug("host rejected active request: %s" % reason)
	network_skill_targets.clear()
	build_hud()
	if active_skill != null:
		state_machine.transition(GameStateMachine.State.SKILL_TARGETING)
		set_skill_hint("요청 거절: %s — 대상을 다시 선택하세요" % reason)
	else:
		state_machine.transition(GameStateMachine.State.PLAYER_AIMING)
		update_hud("스킬 요청 거절: %s" % reason)

func _apply_network_effect_runtime(states: Dictionary) -> void:
	for player_id in [1, 2]:
		for state: Dictionary in states.get(player_id, states.get(str(player_id), [])):
			var augment_id := StringName(str(state.get("id", "")))
			if not augment_manager.has_augment(player_id, augment_id):
				augment_manager.acquire(self, player_id, augment_id)
			for effect: AugmentEffect in augment_manager.effects[player_id]:
				if effect.definition.id == augment_id:
					effect.uses_left = int(state.get("uses", effect.uses_left))
					effect.cooldown_left = int(state.get("cooldown", effect.cooldown_left))

func _sync_network_walls(states: PackedFloat32Array) -> void:
	var signature := str(states)
	if signature == network_wall_signature:
		return
	network_wall_signature = signature
	for wall in temporary_walls:
		if is_instance_valid(wall):
			wall.queue_free()
	temporary_walls.clear()
	for offset in range(0, states.size(), 5):
		if offset + 4 >= states.size():
			break
		var wall := TemporaryWallScript.new() as TemporaryWall
		world.add_child(wall)
		wall.setup(Vector2(states[offset + 1], states[offset + 2]), states[offset + 3], int(states[offset + 4]), int(states[offset]))
		temporary_walls.append(wall)

func update_hud(hint: String) -> void:
	if turn_label == null:
		return
	var player_name: String = AlkkagiPiece.STONE_NAMES[current_player]
	turn_label.text = "%s 차례" % player_name
	turn_label.modulate = AlkkagiPiece.OWNER_COLORS[current_player]
	count_label.text = "라운드 %d  ·  흑돌 %d  ·  백돌 %d" % [round_count, count_owner(1), count_owner(2)]
	hint_label.text = hint

func clear_world() -> void:
	cancel_aim()
	for child in world.get_children() if world else []:
		world.remove_child(child)
		child.queue_free()
	board = null
	hud = null
	turn_label = null
	count_label = null
	hint_label = null
	power_bar = null

func set_screen(next_screen: Control) -> void:
	if screen_root and is_instance_valid(screen_root):
		if screen_root.get_parent() == ui:
			ui.remove_child(screen_root)
		screen_root.queue_free()
	screen_root = next_screen
	ui.add_child(screen_root)

func _panel_root() -> Control:
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return root_control

func _add_background(parent: Control, color: Color = Color("291911")) -> void:
	var background := ColorRect.new()
	background.color = color
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(background)

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(240, 54)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_stylebox_override("normal", _style(Color("70462e"), 10, Color("9c6b43"), 2))
	button.add_theme_stylebox_override("hover", _style(Color("95613c"), 10, Color("e0ad68"), 3))
	button.add_theme_stylebox_override("pressed", _style(Color("563421"), 10, Color("f1c57f"), 2))
	button.add_theme_stylebox_override("disabled", _style(Color("3b302b"), 10, Color("574b45"), 1))
	if callback.is_valid():
		button.pressed.connect(callback)
	return button

func _style(fill: Color, radius: int, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style
