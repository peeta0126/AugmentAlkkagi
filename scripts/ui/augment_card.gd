class_name AugmentCard
extends Control

signal augment_selected(augment_id: StringName)

@export_group("Interaction")
@export var hover_scale := Vector2(1.06, 1.06)
@export_range(0.01, 1.0, 0.01) var hover_duration := 0.14

@onready var background: PanelContainer = %Background
@onready var divider: ColorRect = %Divider
@onready var icon: AugmentIcon = %IconLabel
@onready var name_label: Label = %NameLabel
@onready var rarity_label: Label = %RarityLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var trigger_label: Label = %TriggerLabel
@onready var select_button: Button = %SelectButton

var _definition: AugmentDefinition
var _hovered := false
var _burst: TextureRect
var _burst_tween: Tween
var _hover_tween: Tween
var _enter_tween: Tween


func _ready() -> void:
	select_button.pressed.connect(_on_select_button_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	select_button.mouse_entered.connect(_on_mouse_entered)
	select_button.mouse_exited.connect(_on_select_button_mouse_exited)
	_apply_style()
	_build_burst()
	if _definition:
		_apply_definition()


func setup(definition: AugmentDefinition) -> void:
	_definition = definition
	if is_node_ready():
		_apply_definition()


## 선택 화면에서 카드를 순서대로 튀어나오게 한다(메인 메뉴 버튼과 같은 통통 튀는 느낌).
func play_enter(delay: float) -> void:
	pivot_offset = size * 0.5
	scale = Vector2(0.86, 0.86)
	modulate.a = 0.0
	if _enter_tween:
		_enter_tween.kill()
	_enter_tween = create_tween().set_parallel(true)
	_enter_tween.tween_property(self, "modulate:a", 1.0, 0.16).set_delay(delay)
	_enter_tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _apply_style() -> void:
	background.add_theme_stylebox_override("panel", InkStyle.panel(34.0, 0.0))
	divider.color = Color(InkStyle.TAN, 0.4)
	InkStyle.outline_label(name_label, 30, InkStyle.CREAM, 9)
	description_label.add_theme_color_override("default_color", InkStyle.CREAM_SOFT)
	description_label.add_theme_font_size_override("normal_font_size", 18)
	description_label.add_theme_font_size_override("bold_font_size", 18)
	description_label.add_theme_constant_override("line_separation", 8)
	description_label.fit_content = false
	description_label.resized.connect(_rewrap_description)
	trigger_label.add_theme_color_override("font_color", InkStyle.TAN)
	InkStyle.style_button(select_button, 22)
	InkStyle.button_icon_centered(select_button, InkStyle.ICON_SWORDS, 32.0)
	select_button.custom_minimum_size = Vector2(0, 66)


func _apply_definition() -> void:
	icon.setup(_definition)
	name_label.text = _definition.display_name
	# 이름이 한 줄에 들어가는 가장 큰 글자 크기를 고른다(이름 중간에서 줄이 바뀌지 않게).
	var name_font := name_label.get_theme_font("font")
	var name_size := 30
	while name_size > 18 and name_font.get_string_size(_definition.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > 168.0:
		name_size -= 1
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	InkStyle.outline_label(name_label, name_size, InkStyle.CREAM, 9)
	rarity_label.text = "%s · %s" % [_definition.rarity_name(), _definition.kind_name()]
	_rewrap_description()
	trigger_label.text = _definition.trigger_description
	tooltip_text = _definition.description
	select_button.tooltip_text = _definition.description
	rarity_label.add_theme_stylebox_override("normal", InkStyle.pill(_definition.rarity_color()))
	rarity_label.add_theme_color_override("font_color", Color("241913"))
	rarity_label.add_theme_font_size_override("font_size", 16)


func _on_select_button_pressed() -> void:
	if _definition:
		augment_selected.emit(_definition.id)


func _build_burst() -> void:
	# 카드 뒤에서 터지는 주황 폭발(메인 화면의 충돌 장면처럼). 평소엔 숨겨 둔다.
	_burst = TextureRect.new()
	_burst.texture = InkStyle.BURST_TEXTURE
	_burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_burst.stretch_mode = TextureRect.STRETCH_SCALE
	_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst.show_behind_parent = true
	_burst.size = Vector2(450.0, 530.0)
	_burst.pivot_offset = _burst.size * 0.5
	_burst.modulate.a = 0.0
	add_child(_burst)
	move_child(_burst, 0)
	resized.connect(_center_burst)
	_center_burst()


func _center_burst() -> void:
	if _burst:
		_burst.position = size * 0.5 - _burst.size * 0.5


## 튀어나올 때 폭발이 커졌다 돌아오기 때문에(커지는 정도와 회전 포함) 양 끝 카드에서는 화면 밖으로 삐져나가 잘린다.
## 모양과 크기는 그대로 두고, 화면 안에 다 들어오도록 가로 위치만 안쪽으로 민다.
func _keep_burst_on_screen() -> void:
	_center_burst()
	var half_reach := _burst.size.x * 0.5 * 1.14
	var viewport_width := get_viewport_rect().size.x
	var center_x := global_position.x + size.x * 0.5
	var shift := 0.0
	if center_x - half_reach < 0.0:
		shift = half_reach - center_x
	elif center_x + half_reach > viewport_width:
		shift = viewport_width - half_reach - center_x
	_burst.position.x += shift / maxf(scale.x, 0.01)


func _pop_burst(strength: float) -> void:
	if _burst == null:
		return
	z_index = 10  # 옆 카드에 가리지 않고 폭발이 끝까지 보이게 맨 앞으로
	_keep_burst_on_screen()
	if _burst_tween:
		_burst_tween.kill()
	_burst.scale = Vector2(0.55, 0.55)
	_burst.rotation = randf_range(-0.12, 0.12)
	_burst.modulate.a = strength
	_burst_tween = create_tween().set_parallel(true)
	_burst_tween.tween_property(_burst, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_burst() -> void:
	if _burst == null:
		return
	z_index = 0
	if _burst_tween:
		_burst_tween.kill()
	_burst_tween = create_tween()
	_burst_tween.tween_property(_burst, "modulate:a", 0.0, 0.12)


func _on_mouse_entered() -> void:
	if _hovered:
		return  # 카드 안에서 글자·버튼 위로 옮길 때마다 폭발이 처음부터 다시 터지지 않게 한다
	_hovered = true
	background.self_modulate = Color(1.12, 1.08, 1.02)
	_pop_burst(1.0)
	_animate_to(hover_scale)


func _on_mouse_exited() -> void:
	if select_button.is_hovered() or get_global_rect().has_point(get_global_mouse_position()):
		return
	_hovered = false
	background.self_modulate = Color.WHITE
	_hide_burst()
	_animate_to(Vector2.ONE)


func _on_select_button_mouse_exited() -> void:
	if not get_global_rect().has_point(get_global_mouse_position()):
		_on_mouse_exited()


func _animate_to(target_scale: Vector2) -> void:
	pivot_offset = size * 0.5
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", target_scale, hover_duration)


## 문장마다 줄을 나누고, 줄이 넘치면 띄어쓰기에서만 바꾼다(엔진 자동 줄바꿈은 한국어를 글자 중간에서 끊는다).
func _rewrap_description() -> void:
	if _definition == null or description_label == null:
		return
	var width := description_label.size.x
	if width < 40.0:
		return
	var font := description_label.get_theme_font("normal_font")
	var font_size := description_label.get_theme_font_size("normal_font_size")
	var sentences := _definition.description.strip_edges().replace(". ", ".
").replace("! ", "!
").replace("? ", "?
").split("
")
	var lines: PackedStringArray = []
	for sentence in sentences:
		var line := ""
		for word in sentence.split(" ", false):
			var candidate := word if line.is_empty() else line + " " + word
			if line.is_empty() or font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
				line = candidate
			else:
				lines.append(line)
				line = word
		if not line.is_empty():
			lines.append(line)
	var text := _highlight("
".join(lines))
	if description_label.text != text:
		description_label.text = text


## 숫자와 단위(40%, 2회, 3턴, 60px, 1.6배 …)를 주황 굵은 글씨로 강조해서 핵심 수치가 먼저 눈에 들어오게 한다.
func _highlight(text: String) -> String:
	var pattern := RegEx.new()
	pattern.compile(r"(\d+(?:\.\d+)?\s?(?:%|px|배|회|턴|사이클|개|초|도|번)?)")
	var out := ""
	var last := 0
	for m in pattern.search_all(text):
		out += text.substr(last, m.get_start() - last)
		out += "[color=#f58a1f]%s[/color]" % m.get_string()
		last = m.get_end()
	out += text.substr(last)
	return out
