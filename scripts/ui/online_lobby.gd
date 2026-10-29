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
