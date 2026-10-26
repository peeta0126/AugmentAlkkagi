class_name MainMenu
extends Control

signal developer_mode_requested
signal local_setup_requested
signal online_room_create_requested
signal online_room_join_requested
signal lan_menu_requested
signal settings_requested
signal quit_requested

@onready var developer_mode_button: Button = %DeveloperModeButton
@onready var local_game_button: Button = %LocalGameButton
@onready var create_online_room_button: Button = %CreateOnlineRoomButton
@onready var join_online_room_button: Button = %JoinOnlineRoomButton
@onready var lan_menu_button: Button = %LanMenuButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	developer_mode_button.pressed.connect(func(): developer_mode_requested.emit())
	local_game_button.pressed.connect(func(): local_setup_requested.emit())
	create_online_room_button.pressed.connect(func(): online_room_create_requested.emit())
	join_online_room_button.pressed.connect(func(): online_room_join_requested.emit())
	lan_menu_button.pressed.connect(func(): lan_menu_requested.emit())
	settings_button.pressed.connect(func(): settings_requested.emit())
	quit_button.pressed.connect(func(): quit_requested.emit())
