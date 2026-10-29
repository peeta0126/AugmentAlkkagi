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
@onready var description_label: Label = %DescriptionLabel
@onready var trigger_label: Label = %TriggerLabel
@onready var select_button: Button = %SelectButton

var _definition: AugmentDefinition
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
	description_label.add_theme_color_override("font_color", InkStyle.CREAM_SOFT)
	trigger_label.add_theme_color_override("font_color", InkStyle.TAN)
	InkStyle.style_button(select_button, 22)
	InkStyle.button_icon(select_button, InkStyle.ICON_SWORDS, 30)
	select_button.custom_minimum_size = Vector2(0, 56)


func _apply_definition() -> void:
	icon.setup(_definition)
	name_label.text = _definition.display_name
	var length := _definition.display_name.length()
	InkStyle.outline_label(name_label, 30 if length <= 6 else (26 if length <= 9 else 22), InkStyle.CREAM, 9)
	rarity_label.text = "%s · %s" % [_definition.rarity_name(), _definition.kind_name()]
	description_label.text = _definition.description
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


func _pop_burst(strength: float) -> void:
	if _burst == null:
		return
	z_index = 10  # 옆 카드에 가리지 않고 폭발이 끝까지 보이게 맨 앞으로
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
	background.self_modulate = Color(1.12, 1.08, 1.02)
	_pop_burst(1.0)
	_animate_to(hover_scale)


func _on_mouse_exited() -> void:
	if select_button.is_hovered():
		return
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
