class_name DeveloperAugmentSelection
extends Control

signal augment_selected(augment_id: StringName)
signal back_requested

const AugmentCardScene := preload("res://scenes/ui/augment_card.tscn")

var grid: GridContainer

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.055, 0.035, 0.025, 0.98)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var title := Label.new()
	title.text = "개발자 모드 · 증강 선택"
	title.position = Vector2(200, 28)
	title.size = Vector2(880, 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("f4d79a"))
	title.add_theme_font_size_override("font_size", 34)
	add_child(title)

	var instruction := Label.new()
	instruction.text = "선택한 증강이 흑돌과 백돌 모두에게 적용됩니다. 두 플레이어가 번갈아 직접 시험할 수 있습니다."
	instruction.position = Vector2(80, 82)
	instruction.size = Vector2(1120, 30)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.add_theme_color_override("font_color", Color("dac7ae"))
	instruction.add_theme_font_size_override("font_size", 17)
	add_child(instruction)

	var scroll := ScrollContainer.new()
	# 카드 3열(316×3 + 간격 36 = 984)에 양옆 여백 20씩을 더한 폭을 화면 가운데에 둔다.
	const GRID_WIDTH := 984.0
	const SIDE_MARGIN := 20.0
	var scroll_width := GRID_WIDTH + SIDE_MARGIN * 2.0
	scroll.position = Vector2((1280.0 - scroll_width) * 0.5, 124)
	scroll.size = Vector2(scroll_width, 510)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(SIDE_MARGIN))
	margin.add_theme_constant_override("margin_right", int(SIDE_MARGIN))
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	scroll.add_child(margin)

	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 16)
	margin.add_child(grid)

	var back := Button.new()
	back.text = "메인 메뉴로"
	back.position = Vector2(520, 650)
	back.size = Vector2(240, 48)
	back.add_theme_color_override("font_color", Color("f3e7d3"))
	back.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.set_border_width_all(1)
		style.bg_color = Color("2b2018") if state == "hover" else Color(0, 0, 0, 0)
		style.border_color = Color("c9b99c") if state == "hover" else Color("6f5c3f")
		back.add_theme_stylebox_override(state, style)
	back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	back.pressed.connect(func(): back_requested.emit())
	add_child(back)

func setup(definitions: Array[AugmentDefinition]) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for definition in definitions:
		if not definition.enabled:
			continue
		var card := AugmentCardScene.instantiate() as AugmentCard
		card.setup(definition)
		card.augment_selected.connect(_on_augment_selected)
		grid.add_child(card)

func _on_augment_selected(augment_id: StringName) -> void:
	augment_selected.emit(augment_id)