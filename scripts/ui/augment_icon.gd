class_name AugmentIcon
extends Control
## 증강 아이콘: 등급별 금속 테두리 위에 증강 그림을 얹는다. 그림 파일이 없으면 글자 아이콘으로 대신한다.

const ICON_DIR := "res://assets/augments/icons/"
const FRAME_FILES := ["frame_0.png", "frame_1.png", "frame_2.png", "frame_3.png"]
const GLYPH_SCALE := 0.66

var _frame: TextureRect
var _glyph: TextureRect
var _fallback: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = _make_rect()
	_glyph = _make_rect()
	add_child(_frame)
	add_child(_glyph)
	resized.connect(_layout)


func setup(definition: AugmentDefinition) -> void:
	_frame.texture = load(ICON_DIR + FRAME_FILES[clampi(definition.rarity, 0, FRAME_FILES.size() - 1)])
	var glyph_path := "%s%s.png" % [ICON_DIR, definition.id]
	if ResourceLoader.exists(glyph_path):
		_glyph.texture = load(glyph_path)
		_glyph.visible = true
		if _fallback:
			_fallback.visible = false
	else:
		_glyph.visible = false
		if _fallback == null:
			_fallback = Label.new()
			_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_fallback)
		_fallback.text = definition.icon_text
		_fallback.add_theme_color_override("font_color", definition.rarity_color())
		_fallback.visible = true
	_layout()


func _make_rect() -> TextureRect:
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _layout() -> void:
	_frame.position = Vector2.ZERO
	_frame.size = size
	var glyph_size := size * GLYPH_SCALE
	_glyph.size = glyph_size
	_glyph.position = (size - glyph_size) * 0.5
	if _fallback:
		_fallback.add_theme_font_size_override("font_size", int(size.y * 0.42))
