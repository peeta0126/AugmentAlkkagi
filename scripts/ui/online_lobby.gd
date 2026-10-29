class_name OnlineLobby
extends Control

signal room_create_requested
signal room_join_requested(room_code: String)
signal ready_changed(is_ready: bool)
signal game_start_requested
signal piece_count_change_requested(delta: int)
signal mode_change_requested(refresh_enabled: bool, chaos_enabled: bool)
signal leave_requested

@onready var join_panel: PanelContainer = %JoinPanel
@onready var lobby_panel: PanelContainer = %LobbyPanel
@onready var room_code_edit: LineEdit = %RoomCodeEdit
@onready var room_code_label: Label = %RoomCodeLabel
@onready var role_label: Label = %RoleLabel
@onready var black_player_label: Label = %BlackPlayerLabel
@onready var white_player_label: Label = %WhitePlayerLabel
@onready var piece_count_label: Label = %PieceCountLabel
@onready var decrease_piece_button: Button = %DecreasePieceButton
@onready var increase_piece_button: Button = %IncreasePieceButton
@onready var ready_button: Button = %ReadyButton
@onready var start_button: Button = %StartButton
@onready var status_label: Label = %StatusLabel
@onready var refresh_mode_toggle: CheckButton = %RefreshModeToggle
@onready var chaos_mode_toggle: CheckButton = %ChaosModeToggle
@onready var mode_description_label: Label = %ModeDescriptionLabel

var _updating_modes := false
var _interaction_tweens: Dictionary = {}


func _ready() -> void:
	_apply_ink_style()
	_connect_interaction_animations()
	%CreateRoomButton.pressed.connect(func(): room_create_requested.emit())
	%JoinRoomButton.pressed.connect(_on_join_room_pressed)
	%JoinBackButton.pressed.connect(func(): leave_requested.emit())
	decrease_piece_button.pressed.connect(func(): piece_count_change_requested.emit(-1))
	increase_piece_button.pressed.connect(func(): piece_count_change_requested.emit(1))
	ready_button.toggled.connect(_on_ready_toggled)
	refresh_mode_toggle.toggled.connect(_on_mode_toggled)
	chaos_mode_toggle.toggled.connect(_on_mode_toggled)
	start_button.pressed.connect(func(): game_start_requested.emit())
	%LeaveButton.pressed.connect(func(): leave_requested.emit())
	%RoomCodeCopyButton.pressed.connect(_copy_room_code)


func _connect_interaction_animations() -> void:
	for item in find_children("*", "BaseButton", true, false):
		var button := item as BaseButton
		button.mouse_entered.connect(_animate_button.bind(button, true, false))
		button.mouse_exited.connect(_animate_button.bind(button, false, false))
		button.pressed.connect(_animate_button.bind(button, true, true))


func _animate_button(button: BaseButton, hovered: bool, pressed: bool) -> void:
	if not is_instance_valid(button):
		return
	var old_tween: Tween = _interaction_tweens.get(button)
	if old_tween and old_tween.is_running():
		old_tween.kill()
	button.pivot_offset = button.size * 0.5
	var target_scale := Vector2(0.97, 0.97) if pressed else (Vector2(1.035, 1.035) if hovered else Vector2.ONE)
	var target_color := Color(1.12, 1.06, 0.96, 1.0) if hovered else Color.WHITE
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, 0.12 if pressed else 0.18)
	tween.tween_property(button, "modulate", target_color, 0.18)
	_interaction_tweens[button] = tween
	if pressed:
		tween.chain().tween_property(button, "scale", Vector2(1.035, 1.035) if button.is_hovered() else Vector2.ONE, 0.14)


func _copy_room_code() -> void:
	var code := room_code_label.text.get_slice("  ", 1)
	DisplayServer.clipboard_set(code)
	update_status("방 코드 %s를 복사했습니다." % code, false)


func _play_panel_entrance(panel: Control) -> void:
	panel.pivot_offset = panel.size * 0.5
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.985, 0.985)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.28)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.32)


func show_join() -> void:
	join_panel.visible = true
	lobby_panel.visible = false
	_play_panel_entrance(join_panel)
	room_code_edit.text = ""
	room_code_edit.grab_focus()
	update_status("", false)


func show_lobby(room_code: String, is_host: bool, role_text: String, role_color: Color) -> void:
	join_panel.visible = false
	lobby_panel.visible = true
	_play_panel_entrance(lobby_panel)
	set_room_code(room_code)
	role_label.text = role_text
	role_label.add_theme_color_override("font_color", role_color)
	decrease_piece_button.disabled = not is_host
	increase_piece_button.disabled = not is_host
	start_button.visible = is_host
	refresh_mode_toggle.disabled = not is_host
	chaos_mode_toggle.disabled = not is_host
	update_status("GD-Sync 온라인 · 최대 2명", false)


func set_room_code(room_code: String) -> void:
	room_code_label.text = "방 코드  %s" % room_code


func update_lobby(
	ready_state: Dictionary,
	connected_state: Dictionary,
	piece_count: int,
	local_player_id: int,
	can_start: bool,
	refresh_enabled: bool = false,
	chaos_enabled: bool = false
) -> void:
	var guest_status := "준비" if bool(ready_state.get(2, false)) else "대기"
	if not bool(connected_state.get(2, false)):
		guest_status = "접속 대기"
	black_player_label.text = "방장 · 흑돌\n%s" % ("준비" if bool(ready_state.get(1, false)) else "대기")
	white_player_label.text = "참가자 · 백돌\n%s" % guest_status
	piece_count_label.text = "시작 바둑알 %d개" % piece_count
	ready_button.set_pressed_no_signal(bool(ready_state.get(local_player_id, false)))
	ready_button.text = "✓  준비" if ready_button.button_pressed else "준비"
	start_button.disabled = not can_start
	_updating_modes = true
	refresh_mode_toggle.set_pressed_no_signal(refresh_enabled)
	chaos_mode_toggle.set_pressed_no_signal(chaos_enabled)
	_updating_modes = false
	_update_mode_description(refresh_enabled, chaos_enabled)


func update_status(message: String, is_error: bool) -> void:
	status_label.text = message
	status_label.modulate = Color("ff8d7b") if is_error else Color("e9c99a")


func _on_join_room_pressed() -> void:
	room_join_requested.emit(room_code_edit.text)

func _on_ready_toggled(value: bool) -> void:
	ready_button.text = "✓  준비" if value else "준비"
	ready_changed.emit(value)

func _on_mode_toggled(_value: bool) -> void:
	if _updating_modes:
		return
	_update_mode_description(refresh_mode_toggle.button_pressed, chaos_mode_toggle.button_pressed)
	mode_change_requested.emit(refresh_mode_toggle.button_pressed, chaos_mode_toggle.button_pressed)

func _update_mode_description(refresh_enabled: bool, chaos_enabled: bool) -> void:
	var pick_text := "증강 2개 연속 선택" if chaos_enabled else "증강 1개 선택"
	var refresh_text := " · 후보 새로고침 총 1회" if refresh_enabled else ""
	mode_description_label.text = "%s%s" % [pick_text, refresh_text]


## 방 참가 화면을 방 만들기(로비) 화면과 같은 숯색 판·붓 터치 제목·주황 버튼으로 맞춘다.
func _apply_ink_style() -> void:
	join_panel.add_theme_stylebox_override("panel", InkStyle.panel(40.0, 8.0, true))
	var margin := join_panel.get_node("Margin") as MarginContainer
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	var content := margin.get_node("Content") as VBoxContainer
	content.add_theme_constant_override("separation", 20)
	var old_title := content.get_node("JoinTitleLabel") as Label
	var banner := InkStyle.banner("온라인 방 참가", 46, 480.0)
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(banner)
	content.move_child(banner, old_title.get_index())
	old_title.visible = false
	var guide := content.get_node("JoinGuideLabel") as Label
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	InkStyle.outline_label(guide, 20, InkStyle.CREAM_SOFT, 6)
	InkStyle.style_line_edit(room_code_edit, 38)
	room_code_edit.custom_minimum_size = Vector2(360.0, 70.0)
	room_code_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var actions := content.get_node("JoinActions") as HBoxContainer
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	InkStyle.style_button(%CreateRoomButton, 21)
	InkStyle.style_button_primary(%JoinRoomButton, 22)
	InkStyle.style_button(%JoinBackButton, 21)
	%JoinBackButton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	InkStyle.outline_label(status_label, 18, InkStyle.CREAM_SOFT, 5)
	InkStyle.style_toggle(refresh_mode_toggle, 21)
	InkStyle.style_toggle(chaos_mode_toggle, 21)
	# 시트에서 잘라 둔 옛 버튼 그림은 가장자리가 잘려 있어서(특히 오른쪽 테두리) 온전한 조각으로 바꾼다.
	InkStyle.style_button(ready_button, 23)
	InkStyle.style_button(start_button, 23)
	ready_button.add_theme_stylebox_override("pressed", InkStyle.button_box_orange())
	start_button.add_theme_stylebox_override("hover", InkStyle.button_box_orange())
