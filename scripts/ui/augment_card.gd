class_name AugmentCard
extends Control

signal augment_selected(augment_id: StringName)

const PAPER := Color("221912")
const PAPER_HOVER := Color("2b2018")
const INK := Color("f3e7d0")
const INK_SOFT := Color("c9b99c")
const INK_MUTED := Color("8f8068")

@export_group("Interaction")
@export_range(0.0, 20.0, 0.5) var hover_lift := 6.0
@export_range(0.01, 1.0, 0.01) var hover_duration := 0.14

@onready var background: PanelContainer = %Background
@onready var accent_bar: ColorRect = %AccentBar
@onready var divider: ColorRect = %Divider
@onready var icon: AugmentIcon = %IconLabel
@onready var name_label: Label = %NameLabel
@onready var rarity_label: Label = %RarityLabel
@onready var description_label: Label = %DescriptionLabel
@onready var trigger_label: Label = %TriggerLabel
@onready var select_button: Button = %SelectButton

var _definition: AugmentDefinition
var _hovered := false
var _lift := 0.0
var _enter_offset := 0.0
var _hover_tween: Tween
var _enter_tween: Tween


func _ready() -> void:
	select_button.pressed.connect(_on_select_button_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	select_button.mouse_entered.connect(_on_mouse_entered)
	select_button.mouse_exited.connect(_on_select_button_mouse_exited)
	if _definition:
		_apply_definition()
	else:
		_apply_style(Color("d5c7ae"))


func setup(definition: AugmentDefinition) -> void:
	_definition = definition
	if is_node_ready():
		_apply_definition()


## 선택 화면에서 카드를 순서대로 띄울 때 쓴다.
func play_enter(delay: float) -> void:
	background.modulate.a = 0.0
	accent_bar.modulate.a = 0.0
	_enter_offset = 18.0
	_update_offsets()
	if _enter_tween:
		_enter_tween.kill()
	_enter_tween = create_tween().set_parallel(true)
	_enter_tween.tween_property(background, "modulate:a", 1.0, 0.28).set_delay(delay)
	_enter_tween.tween_property(accent_bar, "modulate:a", 1.0, 0.28).set_delay(delay)
	_enter_tween.tween_method(_set_enter_offset, 18.0, 0.0, 0.34).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _apply_definition() -> void:
	icon.setup(_definition)
	name_label.text = _definition.display_name
	rarity_label.text = "%s · %s" % [_definition.rarity_name(), _definition.kind_name()]
	description_label.text = _definition.description
	trigger_label.text = _definition.trigger_description
	tooltip_text = _definition.description
	select_button.tooltip_text = _definition.description
	_apply_style(_definition.rarity_color())


func _apply_style(rarity_color: Color) -> void:
	accent_bar.color = rarity_color
	divider.color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.22)

	name_label.add_theme_color_override("font_color", INK)
	rarity_label.add_theme_color_override("font_color", rarity_color)
	description_label.add_theme_color_override("font_color", INK_SOFT)
	trigger_label.add_theme_color_override("font_color", INK_MUTED)

	_update_background()

	select_button.add_theme_color_override("font_color", INK)
	select_button.add_theme_color_override("font_hover_color", Color.WHITE)
	select_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	select_button.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), rarity_color.darkened(0.45), 1, 4))
	select_button.add_theme_stylebox_override("hover", _box(rarity_color.darkened(0.6), rarity_color, 1, 4))
	select_button.add_theme_stylebox_override("pressed", _box(rarity_color.darkened(0.45), rarity_color.lightened(0.2), 1, 4))
	select_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _update_background() -> void:
	var rarity_color := _definition.rarity_color() if _definition else Color("d5c7ae")
	var style := _box(PAPER_HOVER if _hovered else PAPER, rarity_color if _hovered else rarity_color.darkened(0.55), 1, 6)
	if _hovered:
		style.shadow_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.28)
		style.shadow_size = 18
	elif _definition and _definition.rarity == AugmentDefinition.Rarity.LEGENDARY:
		style.shadow_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.12)
		style.shadow_size = 12
	background.add_theme_stylebox_override("panel", style)


func _box(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _on_select_button_pressed() -> void:
	if _definition:
		augment_selected.emit(_definition.id)


func _on_mouse_entered() -> void:
	if _hovered:
		return
	_hovered = true
	_update_background()
	_animate_lift(hover_lift)


func _on_mouse_exited() -> void:
	if select_button.is_hovered():
		return
	_hovered = false
	_update_background()
	_animate_lift(0.0)


func _on_select_button_mouse_exited() -> void:
	if not get_global_rect().has_point(get_global_mouse_position()):
		_on_mouse_exited()


func _animate_lift(target: float) -> void:
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_method(_set_lift, _lift, target, hover_duration)


func _set_lift(value: float) -> void:
	_lift = value
	_update_offsets()


func _set_enter_offset(value: float) -> void:
	_enter_offset = value
	_update_offsets()


func _update_offsets() -> void:
	var shift := _enter_offset - _lift
	background.offset_top = shift
	background.offset_bottom = shift
	accent_bar.offset_top = shift
	accent_bar.offset_bottom = shift + 3.0
