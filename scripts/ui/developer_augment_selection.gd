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
	scroll.position = Vector2(70, 124)
	scroll.size = Vector2(1140, 510)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)

	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	var back := Button.new()
	back.text = "메인 메뉴로"
	back.position = Vector2(520, 650)
	back.size = Vector2(240, 48)
	back.add_theme_color_override("font_color", Color("f3e7d3"))
	back.add_theme_font_size_override("font_size", 18)
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