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


## 로고 같은 굵은 붓글씨 느낌: 글자를 더 두껍게 하고 오른쪽으로 눕힌 뒤 두꺼운 검정 테두리.
static func brush_label(label: Label, font_size: int, color: Color = CREAM, outline: int = 14) -> void:
	var font := FontVariation.new()
	font.base_font = label.get_theme_font("font")
	font.variation_embolden = 0.9
	font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.2, 1.0), Vector2.ZERO)
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
	brush_label(label, font_size, text_color, 8 if compact else 12)


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
