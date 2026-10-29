class_name InkStyle
extends RefCounted
## 메인·로비 화면과 같은 잉크 일러스트 스타일을 모든 화면에서 똑같이 쓰기 위한 도우미.
## 판과 버튼은 로비 UI 시트(online_lobby_ui_sheet)에서 잘라 낸 조각을 그대로 쓴다.

const PANEL_TEXTURE := preload("res://assets/ui/ink/panel_mid_a.png")
const PANEL_WIDE_TEXTURE := preload("res://assets/ui/ink/panel_large.png")
const BUTTON_DARK := preload("res://assets/ui/ink/btn_dark_a.png")
const BUTTON_DARK_LIGHT := preload("res://assets/ui/ink/btn_dark_d.png")
const BUTTON_ORANGE := preload("res://assets/ui/ink/btn_orange_a.png")
const BUTTON_ORANGE_DEEP := preload("res://assets/ui/ink/btn_orange_c.png")
const BOARD_TEXTURE := preload("res://assets/ui/lobby_board.png")
const LOGO_TEXTURE := preload("res://assets/ui/lobby_logo.png")
const ICON_SWORDS := preload("res://assets/ui/icon_local.png")
const ICON_GEAR := preload("res://assets/ui/icon_settings.png")
const ICON_LINK := preload("res://assets/ui/icon_join.png")
const TOGGLE_ON := preload("res://assets/ui/ink/toggle_on.png")
const TOGGLE_OFF := preload("res://assets/ui/ink/toggle_off.png")
const ARROW_LEFT := preload("res://assets/ui/ink/arrow_left.png")
const ARROW_RIGHT := preload("res://assets/ui/ink/arrow_right.png")
const ICON_FLASK := preload("res://assets/ui/icon_developer.png")
const SWASH_TEXTURE := preload("res://assets/ui/swash.png")
const BURST_TEXTURE := preload("res://assets/ui/burst.png")
const VIGNETTE_TEXTURE := preload("res://assets/ui/vignette.png")

const CREAM := Color("f7ecd6")
const CREAM_SOFT := Color("e4d7bd")
const TAN := Color("c9b48f")
const INK := Color("1c1512")
const ORANGE := Color("f58a1f")
const CHARCOAL := Color("2b2928")


## 크림색 이중 테두리를 두른 숯색 판. border: 모서리 두께, inner: 테두리 안쪽에서 글자까지 여백.
static func panel(border: float = 34.0, inner: float = 6.0, wide: bool = false) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = PANEL_WIDE_TEXTURE if wide else PANEL_TEXTURE
	style.set_texture_margin_all(border)
	style.set_content_margin_all(border * 0.62 + inner)
	style.draw_center = true
	return style


static func _button_style(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 34.0
	style.texture_margin_right = 34.0
	style.texture_margin_top = 26.0
	style.texture_margin_bottom = 26.0
	style.draw_center = true
	return style


## 메인 메뉴 버튼처럼: 평소엔 어두운 판, 올리면 주황 판, 누르면 짙은 주황 판.
static func style_button(button: Button, font_size: int = 20) -> void:
	button.add_theme_stylebox_override("normal", _button_style(BUTTON_DARK))
	button.add_theme_stylebox_override("hover", _button_style(BUTTON_ORANGE))
	button.add_theme_stylebox_override("pressed", _button_style(BUTTON_ORANGE_DEEP))
	button.add_theme_stylebox_override("focus", _button_style(BUTTON_ORANGE))
	button.add_theme_stylebox_override("disabled", _button_style(BUTTON_DARK_LIGHT))
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color("241913"))
	button.add_theme_color_override("font_pressed_color", Color("241913"))
	button.add_theme_color_override("font_focus_color", Color("241913"))
	button.add_theme_color_override("font_disabled_color", Color(CREAM, 0.4))
	button.add_theme_font_size_override("font_size", font_size)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 56.0)


## 크림색 글자에 검정 테두리.
static func outline_label(label: Label, font_size: int, color: Color = CREAM, outline: int = 8) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", outline)


## 큰 제목 전용: 글자를 살짝 두껍게 하고 아주 조금 눕힌 뒤 두꺼운 검정 테두리. 작은 글자에는 쓰지 않는다.
static func brush_label(label: Label, font_size: int, color: Color = CREAM, outline: int = 14) -> void:
	var font := FontVariation.new()
	font.base_font = label.get_theme_font("font")
	font.variation_embolden = 0.35
	font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.07, 1.0), Vector2.ZERO)
	label.add_theme_font_override("font", font)
	outline_label(label, font_size, color, outline)


## 등급 표시용 알약: 평평한 색 + 굵은 검정 테두리.
static func pill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 2.0
	return style


## 화면 전체에 깔 나무 보드 배경(어둡게 덮어서 카드가 도드라지게 한다).
static func board_backdrop(parent: Control, darkness: float = 0.5) -> void:
	var board := TextureRect.new()
	board.texture = BOARD_TEXTURE
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_SCALE
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(board)
	parent.move_child(board, 0)
	var veil := ColorRect.new()
	veil.color = Color(0.07, 0.045, 0.03, darkness)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(veil)
	parent.move_child(veil, 1)
	var vignette := TextureRect.new()
	vignette.texture = VIGNETTE_TEXTURE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(vignette)
	parent.move_child(vignette, 2)


## 제목 뒤에 깔리는 붓 터치를 Label의 배경으로 쓴다. compact는 좁은 패널 제목용.
static func swash_box(compact: bool = false) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = SWASH_TEXTURE
	var h := 36.0 if compact else 80.0
	var v := 22.0 if compact else 40.0
	style.texture_margin_left = h
	style.texture_margin_right = h
	style.texture_margin_top = v
	style.texture_margin_bottom = v
	style.content_margin_left = 22.0 if compact else 40.0
	style.content_margin_right = 22.0 if compact else 40.0
	style.content_margin_top = 4.0 if compact else 8.0
	style.content_margin_bottom = 8.0 if compact else 12.0
	style.draw_center = true
	return style


## 붓 터치 위에 크게 눕힌 제목.
static func swash_title(label: Label, font_size: int, text_color: Color = CREAM, compact: bool = false) -> void:
	label.add_theme_stylebox_override("normal", swash_box(compact))
	if compact:
		outline_label(label, font_size, text_color, 7)
	else:
		brush_label(label, font_size, text_color, 12)


## 메인 메뉴 버튼처럼 왼쪽에 크림색 아이콘을 붙인다.
static func button_icon(button: Button, icon: Texture2D, size: int = 30) -> void:
	button.icon = icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", size)
	button.add_theme_constant_override("h_separation", 10)


## 메인 화면 로고를 지정한 높이로 놓는다.
static func logo(parent: Control, position: Vector2, height: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = LOGO_TEXTURE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var ratio := float(LOGO_TEXTURE.get_width()) / maxf(float(LOGO_TEXTURE.get_height()), 1.0)
	rect.size = Vector2(height * ratio, height)
	rect.position = position
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


## 그림을 비율 유지하며 높이에 맞춰 줄인다(테마 아이콘은 자체 크기 조절이 안 돼서 미리 줄여 둔다).
static func scaled_texture(texture: Texture2D, height: float) -> Texture2D:
	var image := texture.get_image()
	var width := int(round(float(image.get_width()) * height / float(image.get_height())))
	image.resize(width, int(height), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


## 로비 시트의 스위치 그림으로 체크 버튼을 바꾼다.
static func style_toggle(toggle: Button, font_size: int = 20) -> void:
	var on := scaled_texture(TOGGLE_ON, 44.0)
	var off := scaled_texture(TOGGLE_OFF, 44.0)
	for name in ["checked", "checked_mirrored", "checked_disabled"]:
		toggle.add_theme_icon_override(name, on)
	for name in ["unchecked", "unchecked_mirrored", "unchecked_disabled"]:
		toggle.add_theme_icon_override(name, off)
	toggle.add_theme_font_size_override("font_size", font_size)
	for color_name in ["font_color", "font_focus_color", "font_pressed_color"]:
		toggle.add_theme_color_override(color_name, CREAM)
	for color_name in ["font_hover_color", "font_hover_pressed_color"]:
		toggle.add_theme_color_override(color_name, Color.WHITE)
	toggle.add_theme_color_override("font_outline_color", INK)
	toggle.add_theme_constant_override("outline_size", 5)
	toggle.add_theme_constant_override("h_separation", 14)
	toggle.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## 슬라이더: 어두운 홈에 주황 채움, 손잡이는 흰 바둑돌.
static func style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = CHARCOAL
	track.border_color = INK
	track.set_border_width_all(3)
	track.set_corner_radius_all(8)
	track.content_margin_top = 8.0
	track.content_margin_bottom = 8.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = ORANGE
	fill.border_color = INK
	fill.set_border_width_all(3)
	fill.set_corner_radius_all(8)
	fill.content_margin_top = 8.0
	fill.content_margin_bottom = 8.0
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var stone := scaled_texture(load("res://assets/ui/ink/stone_white.png"), 38.0)
	slider.add_theme_icon_override("grabber", stone)
	slider.add_theme_icon_override("grabber_highlight", stone)


## 로비 시트의 주황 화살표 버튼.
static func arrow_button(left: bool, callback: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = ARROW_LEFT if left else ARROW_RIGHT
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = Vector2(62, 62)
	button.modulate = Color.WHITE
	button.mouse_entered.connect(func(): button.modulate = Color(1.15, 1.1, 1.0))
	button.mouse_exited.connect(func(): button.modulate = Color.WHITE)
	button.pressed.connect(callback)
	return button


## 화면 가운데에 놓는 숯색 판(안쪽에 글자와 버튼을 얹는다).
static func center_panel(parent: Control, rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", InkStyle.panel(40.0, 0.0, true))
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel


## 주 행동 버튼(주황 판). 올리면 더 짙은 주황.
static func style_button_primary(button: Button, font_size: int = 22) -> void:
	style_button(button, font_size)
	button.add_theme_stylebox_override("normal", _button_style(BUTTON_ORANGE))
	button.add_theme_stylebox_override("hover", _button_style(BUTTON_ORANGE_DEEP))
	button.add_theme_stylebox_override("pressed", _button_style(BUTTON_ORANGE_DEEP))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, Color("241913"))


## 화면 제목 배너: 붓 터치 위에 큰 제목. 가로 폭을 정하면 가운데 정렬로 쓸 수 있다.
static func banner(text: String, font_size: int = 46, width: float = 640.0) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width, font_size * 2.1)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var swash := TextureRect.new()
	swash.texture = SWASH_TEXTURE
	swash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	swash.stretch_mode = TextureRect.STRETCH_SCALE
	swash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	swash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(swash)
	var label := Label.new()
	label.text = text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_top = -4.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brush_label(label, font_size, CREAM, int(font_size * 0.32))
	holder.add_child(label)
	return holder


## 화면 가운데에 놓는 판과 그 안의 세로 정렬 상자. 반환값은 내용을 넣을 VBoxContainer.
static func centered_card(screen: Control, min_width: float, separation: int = 20) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", InkStyle.panel(40.0, 22.0, true))
	panel.custom_minimum_size = Vector2(min_width, 0.0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	panel.add_child(box)
	return box


## 입력 칸: 어두운 판에 크림 글자, 가운데 정렬.
static func style_line_edit(edit: LineEdit, font_size: int = 32) -> void:
	var box := StyleBoxTexture.new()
	box.texture = BUTTON_DARK
	box.texture_margin_left = 34.0
	box.texture_margin_right = 34.0
	box.texture_margin_top = 26.0
	box.texture_margin_bottom = 26.0
	box.content_margin_left = 30.0
	box.content_margin_right = 30.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	box.draw_center = true
	for state in ["normal", "focus", "read_only"]:
		edit.add_theme_stylebox_override(state, box)
	edit.add_theme_color_override("font_color", CREAM)
	edit.add_theme_color_override("font_placeholder_color", Color(CREAM, 0.35))
	edit.add_theme_color_override("caret_color", ORANGE)
	edit.add_theme_color_override("selection_color", Color(ORANGE, 0.45))
	edit.add_theme_font_size_override("font_size", font_size)
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER


static func button_box_orange() -> StyleBoxTexture:
	return _button_style(BUTTON_ORANGE)
