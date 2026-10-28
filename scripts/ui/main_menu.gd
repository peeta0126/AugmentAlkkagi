@tool
class_name MainMenu
extends Control

signal local_setup_requested
signal online_room_create_requested
signal online_room_join_requested
signal settings_requested
signal developer_mode_requested
signal quit_requested

const UI_ROOT := "res://assets/ui/"
const PANEL_TEXTURE := preload("res://assets/ui/menu_panel.png")
const DARK_BUTTON_TEXTURE := preload("res://assets/ui/button_dark.png")
const ORANGE_BUTTON_TEXTURE := preload("res://assets/ui/button_orange.png")
var active_tweens: Dictionary = {}
var board_visual: TextureRect
var logo_visual: TextureRect
var panel_visual: PanelContainer
var menu_buttons: Array[Button] = []
var menu_icons: Array[TextureRect] = []

func _ready() -> void:
	if has_node("Backdrop"):
		_collect_existing_lobby()
		_wire_existing_buttons()
	else:
		_build_lobby()

func _build_lobby() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color("211c19")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	board_visual = TextureRect.new()
	var board := board_visual
	board.name = "BoardImage"
	board.texture = load(UI_ROOT + "lobby_board.png")
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_SCALE
	board.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)

	logo_visual = TextureRect.new()
	var logo := logo_visual
	logo.name = "LogoImage"
	logo.texture = load(UI_ROOT + "lobby_logo.png")
	logo.position = Vector2(320, 26)
	logo.size = Vector2(640, 205)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)

	panel_visual = PanelContainer.new()
	var menu_panel := panel_visual
	menu_panel.name = "MenuPanel"
	menu_panel.position = Vector2(814, 14)
	menu_panel.size = Vector2(452, 692)
	menu_panel.add_theme_stylebox_override("panel", _panel_style())
	menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.visible = false
	add_child(menu_panel)

	var title := _label("게임 시작", 37, Color("f7eee1"))
	title.name = "TitleLabel"
	title.position = Vector2(854, 54)
	title.size = Vector2(360, 52)
	title.visible = false
	add_child(title)
	var subtitle := _label("플레이 방식을 선택하세요.", 18, Color("c5b8aa"))
	subtitle.name = "SubtitleLabel"
	subtitle.position = Vector2(857, 109)
	subtitle.size = Vector2(360, 30)
	subtitle.visible = false
	add_child(subtitle)

	_make_button("로컬 대전 시작", "icon_local.png", Vector2(460, 248), false, "LocalButton", 54)
	_make_button("온라인 방 만들기", "icon_online.png", Vector2(460, 311), false, "OnlineCreateButton", 54)
	_make_button("6자리 방 코드 참가", "icon_join.png", Vector2(460, 374), false, "JoinButton", 54)
	_make_button("설정", "icon_settings.png", Vector2(460, 437), false, "SettingsButton", 54)
	_make_button("게임 종료", "icon_quit.png", Vector2(460, 500), false, "QuitButton", 54)

	var divider := ColorRect.new()
	divider.name = "DeveloperDivider"
	divider.position = Vector2(460, 570)
	divider.size = Vector2(380, 2)
	divider.color = Color("a58a73")
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.visible = false
	add_child(divider)
	var developer_label := _label("DEVELOPER TOOLS", 12, Color("a99480"))
	developer_label.name = "DeveloperToolsLabel"
	developer_label.position = Vector2(480, 570)
	developer_label.size = Vector2(320, 22)
	add_child(developer_label)
	_make_button("증강 테스트 모드", "icon_developer.png", Vector2(460, 598), false, "DeveloperButton", 54)

	_set_scene_owners(self)
	_wire_existing_buttons()


func _set_scene_owners(node: Node) -> void:
	if Engine.is_editor_hint():
		for child in node.get_children():
			child.owner = self
			_set_scene_owners(child)


func _collect_existing_lobby() -> void:
	board_visual = get_node_or_null("BoardImage") as TextureRect
	logo_visual = get_node_or_null("LogoImage") as TextureRect
	panel_visual = get_node_or_null("MenuPanel") as PanelContainer
	if not has_node("DeveloperToolsLabel"):
		var developer_label := _label("DEVELOPER TOOLS", 12, Color("a99480"))
		developer_label.name = "DeveloperToolsLabel"
		developer_label.position = Vector2(480, 570)
		developer_label.size = Vector2(320, 22)
		add_child(developer_label)
		if Engine.is_editor_hint():
			developer_label.owner = self
	menu_buttons.clear()
	menu_icons.clear()
	for button_name in ["LocalButton", "OnlineCreateButton", "JoinButton", "SettingsButton", "QuitButton", "DeveloperButton"]:
		var button := get_node_or_null(button_name) as Button
		if button == null:
			continue
		menu_buttons.append(button)
		var icon := button.get_node_or_null("Icon") as TextureRect
		if icon != null:
			menu_icons.append(icon)


func _wire_existing_buttons() -> void:
	for button in menu_buttons:
		var action := _button_action.bind(button.name)
		if not button.pressed.is_connected(action):
			button.pressed.connect(action)
		var hover_enter := _button_hover_enter.bind(button)
		if not button.mouse_entered.is_connected(hover_enter):
			button.mouse_entered.connect(hover_enter)
		var hover_exit := _button_hover_exit.bind(button)
		if not button.mouse_exited.is_connected(hover_exit):
			button.mouse_exited.connect(hover_exit)


func _button_action(button_name: String) -> void:
	match button_name:
		"LocalButton": local_setup_requested.emit()
		"OnlineCreateButton": online_room_create_requested.emit()
		"JoinButton": online_room_join_requested.emit()
		"SettingsButton": settings_requested.emit()
		"QuitButton": quit_requested.emit()
		"DeveloperButton": developer_mode_requested.emit()


func _button_hover_enter(button: Button) -> void:
	_animate_button(button, Vector2(1.035, 1.07))


func _button_hover_exit(button: Button) -> void:
	_animate_button(button, Vector2.ONE)
func _panel_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = PANEL_TEXTURE
	style.texture_margin_left = 28.0
	style.texture_margin_top = 28.0
	style.texture_margin_right = 28.0
	style.texture_margin_bottom = 28.0
	style.draw_center = true
	return style

func _button_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 22.0
	style.texture_margin_top = 20.0
	style.texture_margin_right = 22.0
	style.texture_margin_bottom = 20.0
	style.draw_center = true
	return style

func _make_button(text: String, icon_file: String, button_position: Vector2, primary: bool, button_name: String, button_height: float = 52.0) -> Button:
	var button := Button.new()
	button.name = button_name
	button.position = button_position
	button.size = Vector2(360, button_height)
	button.set_meta("base_position", button_position)
	button.set_meta("base_size", button.size)
	button.pivot_offset = button.size * 0.5
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", _button_style(ORANGE_BUTTON_TEXTURE if primary else DARK_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("hover", _button_style(ORANGE_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("pressed", _button_style(ORANGE_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("focus", _button_style(ORANGE_BUTTON_TEXTURE))
	button.add_theme_stylebox_override("disabled", _button_style(DARK_BUTTON_TEXTURE))
	button.pressed.connect(_button_action.bind(button.name))
	button.mouse_entered.connect(_button_hover_enter.bind(button))
	button.mouse_exited.connect(_button_hover_exit.bind(button))
	add_child(button)
	menu_buttons.append(button)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = load(UI_ROOT + icon_file)
	icon.position = Vector2(16, 7)
	icon.size = Vector2(40, 40)
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	menu_icons.append(icon)

	var label := Label.new()
	label.name = "Text"
	label.text = text
	label.position = Vector2.ZERO
	label.size = Vector2(360, button_height)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("241913") if primary else Color("f5eadb"))
	label.add_theme_font_size_override("font_size", 22)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	return button

func _animate_button(button: Button, target_scale: Vector2) -> void:
	if active_tweens.has(button):
		var previous: Tween = active_tweens[button]
		if previous.is_running():
			previous.kill()
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tweens[button] = tween
	tween.tween_property(button, "scale", target_scale, 0.14)
	tween.finished.connect(func(): active_tweens.erase(button))

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
