class_name AugmentSelection
extends Control

signal augment_selected(augment_id: StringName)
signal refresh_requested

const LAYOUT_SIZE := Vector2(1280.0, 870.0)

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
	resized.connect(_fit_layout)
	_fit_layout()
	# Keep the status above the independent refresh button.
	refresh_status_label.get_parent().move_child(refresh_status_label, 0)
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
	instruction_label.text = (
		"게임 시작 증강을 하나 선택하세요"
		if _is_initial
		else "%d라운드 완료 보상 — 양쪽 모두 선택해야 재개됩니다" % _round_count
	)
	progress_label.text = "%d/%d" % [_pick_index, _pick_total]
	progress_label.visible = _pick_total > 1
	$Layout/BodyMargin/Body/RefreshArea.visible = _refresh_enabled
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
	# 메인 화면과 같은 나무 보드를 어둡게 깔아 카드가 도드라지게 한다.
	var old_background := get_node_or_null("Background")
	if old_background:
		old_background.visible = false
	InkStyle.board_backdrop(self, 0.6)


func _style_chrome() -> void:
	InkStyle.brush_label(title_label, 52, InkStyle.CREAM, 16)
	title_label.pivot_offset = title_label.size * 0.5
	title_label.rotation_degrees = -1.0
	InkStyle.outline_label(instruction_label, 19, InkStyle.CREAM_SOFT, 6)
	# 로고 밑줄처럼 제목 뒤에 크게 깔리는 주황 붓 터치.
	var swash := TextureRect.new()
	swash.texture = InkStyle.SWASH_TEXTURE
	swash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	swash.stretch_mode = TextureRect.STRETCH_SCALE
	swash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swash.position = Vector2(640.0 - 360.0, 26.0)
	swash.size = Vector2(720.0, 118.0)
	swash.pivot_offset = swash.size * 0.5
	swash.rotation_degrees = -1.0
	$Layout.add_child(swash)
	$Layout.move_child(swash, title_label.get_index())
	_title_rule = ColorRect.new()
	InkStyle.outline_label(progress_label, 28, InkStyle.ORANGE, 8)
	var footer := get_node_or_null("Layout/BodyMargin/Body/FooterLabel") as Label
	if footer:
		InkStyle.outline_label(footer, 15, InkStyle.CREAM_SOFT, 5)
	InkStyle.outline_label(refresh_status_label, 16, InkStyle.CREAM_SOFT, 5)
	InkStyle.style_button(refresh_button, 19)
	InkStyle.button_icon(refresh_button, InkStyle.ICON_LINK, 28)


func _on_card_selected(augment_id: StringName) -> void:
	augment_selected.emit(augment_id)

func set_interaction_enabled(value: bool) -> void:
	for child in card_area.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	refresh_button.disabled = not value or not _refresh_available


func _fit_layout() -> void:
	var fit := minf(size.x / LAYOUT_SIZE.x, size.y / LAYOUT_SIZE.y)
	$Layout.scale = Vector2.ONE * fit
	$Layout.position = (size - LAYOUT_SIZE * fit) * 0.5
