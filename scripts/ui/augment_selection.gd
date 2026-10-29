class_name AugmentSelection
extends Control

signal augment_selected(augment_id: StringName)
signal refresh_requested

const AugmentCardScene := preload("res://scenes/ui/augment_card.tscn")

@export_group("Transition")
@export_range(0.0, 1.0, 0.01) var fade_duration := 0.22

@onready var title_label: Label = %TitleLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var card_area: HBoxContainer = %CardArea
@onready var progress_label: Label = %ProgressLabel
@onready var refresh_button: Button = %RefreshButton
@onready var refresh_status_label: Label = %RefreshStatusLabel

var _player_name := ""
var _player_color := Color.WHITE
var _choices: Array[AugmentDefinition] = []
var _is_initial := true
var _round_count := 0
var _is_configured := false
var _pick_index := 1
var _pick_total := 1
var _refresh_enabled := false
var _refresh_available := false
var _title_rule: ColorRect


func _ready() -> void:
	refresh_button.pressed.connect(func(): refresh_requested.emit())
	_build_backdrop()
	_style_chrome()
	if _is_configured:
		_apply_content()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, fade_duration)


func setup(
	player_name: String,
	player_color: Color,
	choices: Array[AugmentDefinition],
	is_initial: bool,
	round_count: int,
	pick_index: int = 1,
	pick_total: int = 1,
	refresh_enabled: bool = false,
	refresh_available: bool = false
) -> void:
	_player_name = player_name
	_player_color = player_color
	_choices = choices.duplicate()
	_is_initial = is_initial
	_round_count = round_count
	_pick_index = pick_index
	_pick_total = pick_total
	_refresh_enabled = refresh_enabled
	_refresh_available = refresh_available
	_is_configured = true
	if is_node_ready():
		_apply_content()


func _apply_content() -> void:
	title_label.text = "%s · 증강 선택" % _player_name
	_title_rule.color = _player_color.lightened(0.15)
	instruction_label.text = (
		"게임 시작 증강을 하나 선택하세요"
		if _is_initial
		else "%d라운드 완료 보상 — 양쪽 모두 선택해야 재개됩니다" % _round_count
	)
	progress_label.text = "%d/%d" % [_pick_index, _pick_total]
	progress_label.visible = _pick_total > 1
	refresh_button.visible = _refresh_enabled
	refresh_button.disabled = not _refresh_available
	refresh_status_label.visible = _refresh_enabled
	refresh_status_label.text = "새로고침 1회 남음" if _refresh_available else "새로고침 사용 완료"

	for child in card_area.get_children():
		card_area.remove_child(child)
		child.queue_free()
	for index in _choices.size():
		var card := AugmentCardScene.instantiate() as AugmentCard
		card.setup(_choices[index])
		card.augment_selected.connect(_on_card_selected)
		card_area.add_child(card)
		card.play_enter(0.1 + 0.09 * index)


func _build_backdrop() -> void:
	# 가장자리로 갈수록 어두워지는 배경. 화면 가운데에 시선이 모이게 한다.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.13, 0.09, 0.06, 1.0))
	gradient.set_color(1, Color(0.035, 0.024, 0.017, 1.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.45)
	texture.fill_to = Vector2(1.0, 1.0)
	texture.width = 256
	texture.height = 256
	var backdrop := TextureRect.new()
	backdrop.texture = texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	move_child(backdrop, 1)


func _style_chrome() -> void:
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color("f3e7d0"))
	instruction_label.add_theme_font_size_override("font_size", 17)
	instruction_label.add_theme_color_override("font_color", Color("a8987c"))
	_title_rule = ColorRect.new()
	_title_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_rule.position = Vector2(640.0 - 20.0, 100.0)
	_title_rule.size = Vector2(40.0, 2.0)
	add_child(_title_rule)
	progress_label.add_theme_font_size_override("font_size", 22)
	progress_label.add_theme_color_override("font_color", Color("c9b99c"))
	var footer := get_node_or_null("FooterLabel") as Label
	if footer:
		footer.add_theme_font_size_override("font_size", 14)
		footer.add_theme_color_override("font_color", Color("6f6350"))
	refresh_status_label.add_theme_color_override("font_color", Color("a8987c"))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.set_border_width_all(1)
		style.bg_color = Color(0, 0, 0, 0) if state != "hover" else Color("2b2018")
		style.border_color = Color("6f5c3f") if state != "hover" else Color("c9b99c")
		if state == "disabled":
			style.border_color = Color("3d3226")
		refresh_button.add_theme_stylebox_override(state, style)
	refresh_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	refresh_button.add_theme_color_override("font_color", Color("e0d2b6"))
	refresh_button.add_theme_color_override("font_disabled_color", Color("6f6350"))
	refresh_button.add_theme_font_size_override("font_size", 17)


func _on_card_selected(augment_id: StringName) -> void:
	augment_selected.emit(augment_id)

func set_interaction_enabled(value: bool) -> void:
	for child in card_area.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	refresh_button.disabled = not value or not _refresh_available
