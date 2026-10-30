class_name GameHud
extends Control

signal menu_requested
signal active_skill_requested(augment_id: StringName)

@onready var turn_label: Label = %TurnLabel
@onready var count_label: Label = %CountLabel
@onready var hint_label: Label = %HintLabel
@onready var power_bar: ProgressBar = %PowerBar
@onready var black_augment_title: Label = %BlackAugmentTitle
@onready var black_augment_items: VBoxContainer = %BlackAugmentItems
@onready var black_augment_progress: Label = %BlackAugmentProgress
@onready var white_augment_title: Label = %WhiteAugmentTitle
@onready var white_augment_items: VBoxContainer = %WhiteAugmentItems
@onready var white_augment_progress: Label = %WhiteAugmentProgress
@onready var active_skills_panel: PanelContainer = %ActiveSkillsPanel
@onready var active_skill_items: VBoxContainer = %ActiveSkillItems
@onready var passive_status_panel: PanelContainer = %PassiveStatusPanel
@onready var passive_status_items: VBoxContainer = %PassiveStatusItems
@onready var mode_status_label: Label = %ModeStatusLabel

var _black_item_template: Label
var _white_item_template: Label
var _active_button_template: Button
var _passive_status_template: Label


func _ready() -> void:
	%MenuButton.pressed.connect(func(): menu_requested.emit())
	_black_item_template = %BlackAugmentItemTemplate
	_white_item_template = %WhiteAugmentItemTemplate
	_active_button_template = %ActiveSkillButtonTemplate
	_passive_status_template = %PassiveStatusTemplate
	_apply_ink_style()
	set_power_percent(0.0)
	# 오른쪽 열은 증강 → 패시브 상태 → 액티브 스킬 순으로 쌓는다.
	var right_column := active_skills_panel.get_parent()
	right_column.move_child(passive_status_panel, active_skills_panel.get_index())


## 메인 화면과 같은 스타일: 숯색 판 + 황갈색 테두리 + 검정 외곽선, 글자는 크림색.
func _apply_ink_style() -> void:
	for panel: PanelContainer in [%BlackAugmentPanel, %WhiteAugmentPanel, passive_status_panel, active_skills_panel]:
		panel.add_theme_stylebox_override("panel", InkStyle.panel(30.0, 0.0))
		var margin := panel.get_node_or_null("Margin") as MarginContainer
		if margin:
			margin.add_theme_constant_override("margin_left", 4)
			margin.add_theme_constant_override("margin_right", 4)
			margin.add_theme_constant_override("margin_top", 2)
			margin.add_theme_constant_override("margin_bottom", 2)
	InkStyle.style_button(%MenuButton, 20)
	InkStyle.button_icon(%MenuButton, InkStyle.ICON_GEAR, 28)
	InkStyle.style_button(_active_button_template, 19)
	InkStyle.button_icon(_active_button_template, InkStyle.ICON_SWORDS, 28)
	mode_status_label.position = Vector2(22.0, 16.0)
	mode_status_label.size = Vector2(300.0, 22.0)
	InkStyle.brush_label(turn_label, 42, InkStyle.CREAM, 14)
	turn_label.pivot_offset = Vector2(220.0, 19.0)
	turn_label.rotation_degrees = 0.0
	var swash := TextureRect.new()
	swash.texture = InkStyle.SWASH_TEXTURE
	swash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	swash.stretch_mode = TextureRect.STRETCH_SCALE
	swash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swash.size = Vector2(500.0, 92.0)
	swash.position = Vector2(640.0 - 250.0, -6.0)
	swash.pivot_offset = swash.size * 0.5
	swash.rotation_degrees = 0.0
	add_child(swash)
	move_child(swash, turn_label.get_parent().get_index())
	count_label.add_theme_color_override("font_color", InkStyle.CREAM_SOFT)
	mode_status_label.add_theme_color_override("font_color", InkStyle.TAN)
	hint_label.add_theme_color_override("font_color", InkStyle.CREAM)
	for title: Label in [black_augment_title, white_augment_title]:
		InkStyle.outline_label(title, 21, InkStyle.CREAM, 7)
	black_augment_progress.add_theme_color_override("font_color", InkStyle.TAN)
	white_augment_progress.add_theme_color_override("font_color", InkStyle.TAN)
	for title: Label in [%ActiveSkillTitle, passive_status_panel.get_node("Margin/Content/PassiveStatusTitle")]:
		InkStyle.outline_label(title, 20, InkStyle.ORANGE, 7)
	_passive_status_template.add_theme_color_override("font_color", InkStyle.CREAM_SOFT)
	# 위쪽 줄 밑에 주황 선, 파워 막대는 검정 테두리에 주황 채움
	(%TopBar as ColorRect).visible = false
	_build_power_gauge()


## 보유 증강 한 줄: 등급 색 인장 + 이름. 설명은 마우스를 올리면 나온다.
func _augment_row(definition: AugmentDefinition) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.tooltip_text = definition.description
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var icon := AugmentIcon.new()
	icon.custom_minimum_size = Vector2(34, 34)
	icon.size = Vector2(34, 34)
	icon.setup(definition)
	row.add_child(icon)
	var name_label := Label.new()
	name_label.text = definition.display_name
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", InkStyle.CREAM)
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name_label)
	return row


func update_status(turn_text: String, turn_color: Color, count_text: String, hint_text: String) -> void:
	turn_label.text = turn_text
	turn_label.modulate = turn_color
	count_label.text = count_text
	InkStyle.set_wrapped(hint_label, hint_text, 290.0)


func set_hint(text: String) -> void:
	InkStyle.set_wrapped(hint_label, text, 290.0)


func set_power_percent(value: float) -> void:
	power_bar.value = clampf(value, 0.0, 100.0)
	_refresh_power_gauge()

func set_mode_status(text: String) -> void:
	mode_status_label.text = text


func set_player_augments(
	player_id: int,
	player_name: String,
	player_color: Color,
	definitions: Array[AugmentDefinition],
	max_augments: int
) -> void:
	var title := black_augment_title if player_id == 1 else white_augment_title
	var items := black_augment_items if player_id == 1 else white_augment_items
	var progress := black_augment_progress if player_id == 1 else white_augment_progress
	var template := _black_item_template if player_id == 1 else _white_item_template

	title.text = "%s 플레이어 증강" % player_name
	pass
	template.visible = false
	_clear_children(items, template)
	if definitions.is_empty():
		var empty_item := template.duplicate() as Label
		empty_item.visible = true
		empty_item.text = "보유 증강 없음"
		empty_item.add_theme_color_override("font_color", Color("9a8b79"))
		items.add_child(empty_item)
	else:
		for definition in definitions:
			items.add_child(_augment_row(definition))

	var owned_count := definitions.size()
	progress.text = (
		"증강 획득 완료"
		if owned_count >= max_augments
		else "증강 %d / %d" % [owned_count, max_augments]
	)


func set_active_skills(entries: Array[Dictionary]) -> void:
	_active_button_template.visible = false
	_clear_children(active_skill_items, _active_button_template)
	active_skills_panel.visible = not entries.is_empty()
	for entry in entries:
		var button := _active_button_template.duplicate() as Button
		button.visible = true
		var augment_id := StringName(str(entry.get("id", "")))
		button.text = str(entry.get("text", ""))
		button.disabled = bool(entry.get("disabled", false))
		button.tooltip_text = str(entry.get("tooltip", ""))
		button.pressed.connect(_on_active_skill_pressed.bind(augment_id))
		active_skill_items.add_child(button)

func set_passive_statuses(entries: Array[Dictionary]) -> void:
	_passive_status_template.visible = false
	_clear_children(passive_status_items, _passive_status_template)
	passive_status_panel.visible = not entries.is_empty()
	for entry in entries:
		var item := _passive_status_template.duplicate() as Label
		item.visible = true
		InkStyle.set_wrapped(item, str(entry.get("text", "")), 245.0)
		item.tooltip_text = str(entry.get("tooltip", ""))
		passive_status_items.add_child(item)


func _on_active_skill_pressed(augment_id: StringName) -> void:
	active_skill_requested.emit(augment_id)


func _clear_children(container: Container, preserved_child: Node = null) -> void:
	for child in container.get_children():
		if child == preserved_child:
			continue
		container.remove_child(child)
		child.queue_free()


var _power_fill: StyleBoxFlat
var _power_fill_panel: Panel
var _power_number: Label


## 파워 게이지: 크림색 이중 테두리 판 안에 힘에 따라 크림 → 주황 → 빨강으로 변하는 막대와 큰 숫자.
func _build_power_gauge() -> void:
	var frame := StyleBoxTexture.new()
	frame.texture = InkStyle.BUTTON_DARK
	frame.texture_margin_left = 34.0
	frame.texture_margin_right = 34.0
	frame.texture_margin_top = 26.0
	frame.texture_margin_bottom = 26.0
	frame.content_margin_left = 20.0
	frame.content_margin_right = 20.0
	frame.content_margin_top = 14.0
	frame.content_margin_bottom = 14.0
	_power_fill = StyleBoxFlat.new()
	_power_fill.set_corner_radius_all(7)
	_power_fill.border_color = InkStyle.INK
	_power_fill.set_border_width_all(3)
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color(0, 0, 0, 0.35)
	empty.set_corner_radius_all(7)
	power_bar.custom_minimum_size = Vector2(290.0, 56.0)
	power_bar.add_theme_stylebox_override("background", frame)
	power_bar.add_theme_stylebox_override("fill", StyleBoxEmpty.new())
	# 막대는 틀 안쪽에만 그린다(ProgressBar 기본 채움은 틀을 덮는다).
	_power_fill_panel = Panel.new()
	_power_fill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_fill_panel.add_theme_stylebox_override("panel", _power_fill)
	_power_fill_panel.position = Vector2(20.0, 15.0)
	_power_fill_panel.size = Vector2(0.0, 26.0)
	power_bar.add_child(_power_fill_panel)
	var power_title := power_bar.get_parent().get_node_or_null("PowerLabel") as Label
	if power_title:
		InkStyle.outline_label(power_title, 20, InkStyle.ORANGE, 7)
		power_title.text = "발사 힘"
	_power_number = Label.new()
	_power_number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_power_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_power_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	InkStyle.outline_label(_power_number, 24, InkStyle.CREAM, 8)
	power_bar.add_child(_power_number)
	power_bar.show_percentage = false
	power_bar.resized.connect(_refresh_power_gauge)
	_refresh_power_gauge()


func _refresh_power_gauge() -> void:
	if _power_fill == null:
		return
	var power := power_bar.value / 100.0
	# 막대 실제 폭을 따른다(레이아웃이 최소 폭보다 넓혀도 100%에서 끝까지 찬다).
	var inner_width := maxf(power_bar.size.x, power_bar.custom_minimum_size.x) - 31.0
	var inner_height := maxf(power_bar.size.y, power_bar.custom_minimum_size.y) - 25.0
	_power_fill_panel.position = Vector2(15.5, 12.5)
	_power_fill.set_corner_radius_all(int(inner_height * 0.5)) # 틀처럼 양 끝이 둥근 알약 모양
	_power_fill_panel.size = Vector2(maxf(inner_width * power, 0.0), inner_height)
	_power_fill_panel.visible = power > 0.005
	_power_fill.bg_color = InkStyle.CREAM.lerp(InkStyle.ORANGE, clampf(power * 2.0, 0.0, 1.0)).lerp(Color("e0361a"), clampf((power - 0.6) * 2.5, 0.0, 1.0))
	_power_number.text = "%d%%" % int(round(power_bar.value))
