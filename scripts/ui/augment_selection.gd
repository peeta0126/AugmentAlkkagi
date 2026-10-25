class_name AugmentSelection
extends Control

signal augment_selected(augment_id: StringName)

const AugmentCardScene := preload("res://scenes/ui/augment_card.tscn")

@export_group("Transition")
@export_range(0.0, 1.0, 0.01) var fade_duration := 0.22

@onready var title_label: Label = %TitleLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var card_area: HBoxContainer = %CardArea

var _player_name := ""
var _player_color := Color.WHITE
var _choices: Array[AugmentDefinition] = []
var _is_initial := true
var _round_count := 0
var _is_configured := false


func _ready() -> void:
	if _is_configured:
		_apply_content()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, fade_duration)


func setup(
	player_name: String,
	player_color: Color,
	choices: Array[AugmentDefinition],
	is_initial: bool,
	round_count: int
) -> void:
	_player_name = player_name
	_player_color = player_color
	_choices = choices.duplicate()
	_is_initial = is_initial
	_round_count = round_count
	_is_configured = true
	if is_node_ready():
		_apply_content()


func _apply_content() -> void:
	title_label.text = "%s 플레이어 · 증강 선택" % _player_name
	title_label.add_theme_color_override("font_color", _player_color.lightened(0.22))
	instruction_label.text = (
		"게임 시작 증강을 하나 선택하세요"
		if _is_initial
		else "%d라운드 완료 보상 — 양쪽 모두 선택해야 재개됩니다" % _round_count
	)

	for child in card_area.get_children():
		card_area.remove_child(child)
		child.queue_free()
	for definition in _choices:
		var card := AugmentCardScene.instantiate() as AugmentCard
		card.setup(definition)
		card.augment_selected.connect(_on_card_selected)
		card_area.add_child(card)


func _on_card_selected(augment_id: StringName) -> void:
	augment_selected.emit(augment_id)
