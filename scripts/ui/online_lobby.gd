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
@onready var players_label: Label = %PlayersLabel
@onready var piece_count_label: Label = %PieceCountLabel
@onready var decrease_piece_button: Button = %DecreasePieceButton
@onready var increase_piece_button: Button = %IncreasePieceButton
@onready var ready_button: CheckButton = %ReadyButton
@onready var start_button: Button = %StartButton
@onready var status_label: Label = %StatusLabel
@onready var refresh_mode_toggle: CheckButton = %RefreshModeToggle
@onready var chaos_mode_toggle: CheckButton = %ChaosModeToggle
@onready var mode_description_label: Label = %ModeDescriptionLabel

var _updating_modes := false


func _ready() -> void:
	%CreateRoomButton.pressed.connect(func(): room_create_requested.emit())
	%JoinRoomButton.pressed.connect(_on_join_room_pressed)
	%JoinBackButton.pressed.connect(func(): leave_requested.emit())
	decrease_piece_button.pressed.connect(func(): piece_count_change_requested.emit(-1))
	increase_piece_button.pressed.connect(func(): piece_count_change_requested.emit(1))
	ready_button.toggled.connect(func(value: bool): ready_changed.emit(value))
	refresh_mode_toggle.toggled.connect(_on_mode_toggled)
	chaos_mode_toggle.toggled.connect(_on_mode_toggled)
	start_button.pressed.connect(func(): game_start_requested.emit())
	%LeaveButton.pressed.connect(func(): leave_requested.emit())


func show_join() -> void:
	join_panel.visible = true
	lobby_panel.visible = false
	room_code_edit.text = ""
	room_code_edit.grab_focus()
	update_status("", false)


func show_lobby(room_code: String, is_host: bool, role_text: String, role_color: Color) -> void:
	join_panel.visible = false
	lobby_panel.visible = true
	room_code_label.text = "방 코드  %s" % room_code
	role_label.text = role_text
	role_label.add_theme_color_override("font_color", role_color)
	decrease_piece_button.disabled = not is_host
	increase_piece_button.disabled = not is_host
	start_button.visible = is_host
	refresh_mode_toggle.disabled = not is_host
	chaos_mode_toggle.disabled = not is_host
	update_status("GD-Sync 온라인 · 최대 2명", false)


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
	players_label.text = "방장  · 흑돌 · %s\n참가자 · 백돌 · %s" % [
		"준비" if bool(ready_state.get(1, false)) else "대기",
		guest_status,
	]
	piece_count_label.text = "시작 바둑알 %d개" % piece_count
	ready_button.set_pressed_no_signal(bool(ready_state.get(local_player_id, false)))
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

func _on_mode_toggled(_value: bool) -> void:
	if _updating_modes:
		return
	_update_mode_description(refresh_mode_toggle.button_pressed, chaos_mode_toggle.button_pressed)
	mode_change_requested.emit(refresh_mode_toggle.button_pressed, chaos_mode_toggle.button_pressed)

func _update_mode_description(refresh_enabled: bool, chaos_enabled: bool) -> void:
	var pick_text := "증강 2개 연속 선택" if chaos_enabled else "증강 1개 선택"
	var refresh_text := " · 후보 새로고침 총 1회" if refresh_enabled else ""
	mode_description_label.text = "%s%s" % [pick_text, refresh_text]
