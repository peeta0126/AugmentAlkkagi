class_name AugmentCard
extends Control

signal augment_selected(augment_id: StringName)

@export_group("Interaction")
@export var hover_scale := Vector2(1.035, 1.035)
@export_range(0.01, 1.0, 0.01) var hover_duration := 0.12

@export_group("Card Styles")
@export var hover_style: StyleBoxFlat

@onready var background: PanelContainer = %Background
@onready var icon_label: Label = %IconLabel
@onready var name_label: Label = %NameLabel
@onready var rarity_label: Label = %RarityLabel
@onready var description_label: Label = %DescriptionLabel
@onready var trigger_label: Label = %TriggerLabel
@onready var select_button: Button = %SelectButton

var _definition: AugmentDefinition
var _normal_style: StyleBoxFlat
var _hover_tween: Tween


func _ready() -> void:
	_normal_style = background.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	select_button.pressed.connect(_on_select_button_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	select_button.mouse_entered.connect(_on_mouse_entered)
	select_button.mouse_exited.connect(_on_select_button_mouse_exited)
	if _definition:
		_apply_definition()


func setup(definition: AugmentDefinition) -> void:
	_definition = definition
	if is_node_ready():
		_apply_definition()


func _apply_definition() -> void:
	icon_label.text = _definition.icon_text
	name_label.text = _definition.display_name
	rarity_label.text = "[%s]" % _definition.rarity_name()
	description_label.text = _definition.description
	trigger_label.text = _definition.trigger_description
	tooltip_text = _definition.description
	select_button.tooltip_text = _definition.description

	var rarity_color := _definition.rarity_color()
	rarity_label.add_theme_color_override("font_color", rarity_color)
	_normal_style.border_color = rarity_color.darkened(0.28)
	background.add_theme_stylebox_override("panel", _normal_style)


func _on_select_button_pressed() -> void:
	if _definition:
		augment_selected.emit(_definition.id)


func _on_mouse_entered() -> void:
	var style := _normal_style
	if hover_style:
		style = hover_style.duplicate() as StyleBoxFlat
		if _definition:
			style.border_color = _definition.rarity_color()
	background.add_theme_stylebox_override("panel", style)
	_animate_to(hover_scale)


func _on_mouse_exited() -> void:
	if select_button.is_hovered():
		return
	background.add_theme_stylebox_override("panel", _normal_style)
	_animate_to(Vector2.ONE)


func _on_select_button_mouse_exited() -> void:
	if not get_global_rect().has_point(get_global_mouse_position()):
		_on_mouse_exited()


func _animate_to(target_scale: Vector2) -> void:
	pivot_offset = size * 0.5
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", target_scale, hover_duration)
