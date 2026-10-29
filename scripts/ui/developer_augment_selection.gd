class_name DeveloperAugmentSelection
extends Control

signal augment_selected(augment_id: StringName)
signal back_requested

const AugmentCardScene := preload("res://scenes/ui/augment_card.tscn")

var grid: GridContainer

func _ready() -> void:
	InkStyle.board_backdrop(self, 0.62)
	var swash := TextureRect.new()
	swash.texture = InkStyle.SWASH_TEXTURE
	swash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	swash.stretch_mode = TextureRect.STRETCH_SCALE
	swash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swash.position = Vector2(640.0 - 400.0, 4.0)
	swash.size = Vector2(800.0, 112.0)
	swash.rotation_degrees = -0.5
	swash.pivot_offset = swash.size * 0.5
	add_child(swash)

	var title := Label.new()
	title.text = "개발자 모드 · 증강 선택"
	title.position = Vector2(200, 28)
	title.size = Vector2(880, 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(200, 24)
	InkStyle.brush_label(title, 40, InkStyle.CREAM, 12)
	title.pivot_offset = title.size * 0.5
	title.rotation_degrees = -0.5
	add_child(title)

	var instruction := Label.new()
	instruction.text = "선택한 증강이 흑돌과 백돌 모두에게 적용됩니다. 두 플레이어가 번갈아 직접 시험할 수 있습니다."
	instruction.position = Vector2(80, 82)
	instruction.size = Vector2(1120, 30)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.position = Vector2(80, 98)
	InkStyle.outline_label(instruction, 18, InkStyle.CREAM_SOFT, 6)
	add_child(instruction)

	var scroll := ScrollContainer.new()
	# 스크롤 영역은 안쪽 내용을 잘라 내기 때문에, 카드 뒤로 튀는 폭발(카드 둘레 약 65px)이 잘리지 않게
	# 화면 전체 폭을 쓰고 카드 둘레에 그만큼 여백을 둔다. 카드 3열 폭은 326×3 + 간격 36 = 1014.
	const GRID_WIDTH := 1014.0
	const BURST_ROOM := 72.0
	var side_margin := (1280.0 - GRID_WIDTH) * 0.5
	scroll.position = Vector2(0, 96)
	scroll.size = Vector2(1280.0, 524)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(side_margin))
	margin.add_theme_constant_override("margin_right", int(side_margin))
	margin.add_theme_constant_override("margin_top", int(BURST_ROOM))
	margin.add_theme_constant_override("margin_bottom", int(BURST_ROOM))
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
	InkStyle.style_button(back, 22)
	back.size = Vector2(260, 60)
	back.position = Vector2(510, 626)
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