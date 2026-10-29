class_name AlkkagiBoard
extends Node2D

const BlizzardScene := preload("res://scenes/effects/blizzard.tscn")
const EarthquakeScene := preload("res://scenes/effects/earthquake.tscn")
const GravityFieldScene := preload("res://scenes/effects/gravity_field.tscn")
const WishScene := preload("res://scenes/effects/wish.tscn")
const TrainScene := preload("res://scenes/effects/train.tscn")

# 한국 일반 바둑판 420×450mm를 1mm = 1.2px로 환산한 물리 규격이다.
const BOARD_SIZE := Vector2(504.0, 540.0)
const BOARD_RECT := Rect2(Vector2(388.0, 96.0), BOARD_SIZE)
const GRID_MARGIN := Vector2(25.2, 27.0)
const GRID_RECT := Rect2(BOARD_RECT.position + GRID_MARGIN, BOARD_RECT.size - GRID_MARGIN * 2.0)
const GRID_COUNT := 19
const STAR_INDICES := [3, 9, 15]

var aim_origin := Vector2.ZERO
var aim_pointer := Vector2.ZERO
var show_aim := false
var active_color := Color("d6ad62")
var aim_max_drag := GameplayRules.BALANCE.drag_distance
var guide_multiplier := 1.0
var empowered_aim := false
var effect_lines: Array[Dictionary] = []
var blizzard_active := false
var blizzard_visual: BlizzardVisual
var field_visuals: Dictionary = {}
var field_visual_nodes: Dictionary = {}
var placement_active := false
var placement_preview_position := Vector2.ZERO
var placement_preview_radius := 0.0
var placement_preview_valid := false
var placement_preview_visible := false

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	var changed := false
	for item in effect_lines:
		item.time = float(item.time) - delta
		changed = true
	effect_lines = effect_lines.filter(func(item: Dictionary): return float(item.time) > 0.0)
	if changed or blizzard_active:
		queue_redraw()

func add_effect_line(from: Vector2, to: Vector2, color: Color, duration: float = 0.45, width: float = 4.0) -> void:
	effect_lines.append({"from": from, "to": to, "color": color, "time": duration, "width": width})
	queue_redraw()

func set_blizzard(active: bool) -> void:
	if blizzard_active == active:
		return
	blizzard_active = active
	if active:
		blizzard_visual = BlizzardScene.instantiate() as BlizzardVisual
		add_child(blizzard_visual)
	elif is_instance_valid(blizzard_visual):
		blizzard_visual.stop()
		blizzard_visual = null

func set_field_visual(key: String, data: Dictionary) -> void:
	field_visuals[key] = data
	if str(data.get("type", "")) == "cracks":
		var earthquake: EarthquakeVisual = field_visual_nodes.get(key) as EarthquakeVisual
		if earthquake == null:
			earthquake = EarthquakeScene.instantiate() as EarthquakeVisual
			field_visual_nodes[key] = earthquake
			add_child(earthquake)
		earthquake.configure(data)
	elif str(data.get("type", "")) == "gravity":
		var gravity: GravityFieldVisual = field_visual_nodes.get(key) as GravityFieldVisual
		if gravity == null:
			gravity = GravityFieldScene.instantiate() as GravityFieldVisual
			field_visual_nodes[key] = gravity
			add_child(gravity)
		gravity.configure(data)
	elif str(data.get("type", "")) == "dragon_balls":
		var wish: WishVisual = field_visual_nodes.get(key) as WishVisual
		if wish == null:
			wish = WishScene.instantiate() as WishVisual
			field_visual_nodes[key] = wish
			add_child(wish)
		wish.configure(data)
	elif str(data.get("type", "")) == "train_warning":
		var train: TrainVisual = field_visual_nodes.get(key) as TrainVisual
		if train == null:
			train = TrainScene.instantiate() as TrainVisual
			field_visual_nodes[key] = train
			add_child(train)
		train.show_warning(data.get("from", Vector2.ZERO), data.get("to", Vector2.RIGHT * 504.0))
	queue_redraw()

func remove_field_visual(key: String) -> void:
	field_visuals.erase(key)
	var visual: Node = field_visual_nodes.get(key) as Node
	if is_instance_valid(visual):
		visual.queue_free()
	field_visual_nodes.erase(key)
	queue_redraw()

func set_aim(origin: Vector2, pointer: Vector2, color: Color, max_drag: float = -1.0, guide_scale: float = 1.0, empowered: bool = false) -> void:
	aim_origin = origin
	aim_pointer = pointer
	active_color = color
	aim_max_drag = GameplayRules.BALANCE.drag_distance if max_drag <= 0.0 else max_drag
	guide_multiplier = guide_scale
	empowered_aim = empowered
	show_aim = true
	queue_redraw()

func clear_aim() -> void:
	show_aim = false
	queue_redraw()

func set_placement_active(value: bool) -> void:
	placement_active = value
	if not value:
		placement_preview_visible = false
	queue_redraw()

func set_placement_preview(position: Vector2, radius: float, valid: bool) -> void:
	placement_preview_position = position
	placement_preview_radius = radius
	placement_preview_valid = valid
	placement_preview_visible = true
	queue_redraw()

func clear_placement_preview() -> void:
	placement_preview_visible = false
	queue_redraw()

func grid_point(column: int, row: int) -> Vector2:
	var spacing := GRID_RECT.size / float(GRID_COUNT - 1)
	return GRID_RECT.position + Vector2(spacing.x * column, spacing.y * row)

func _draw() -> void:
	# 보드 밖 배경은 게임 매니저가 깔아 둔 나무 보드 그림이 맡는다.
	# 떠 있는 보드의 부드러운 그림자, 두께, 어두운 측면을 순서대로 그린다.
	draw_style_box(_box(Color(0.06, 0.035, 0.018, 0.42), 13, Color.TRANSPARENT, 0), Rect2(BOARD_RECT.position + Vector2(9, 13), BOARD_RECT.size).grow(11))
	draw_style_box(_box(Color("5a3419"), 10, Color("351d0f"), 4), Rect2(BOARD_RECT.position + Vector2(0, 7), BOARD_RECT.size).grow(9))
	draw_style_box(_box(Color("d1a15f"), 7, Color("70431f"), 3), BOARD_RECT)
	if placement_active:
		var upper := Rect2(BOARD_RECT.position, Vector2(BOARD_RECT.size.x, BOARD_RECT.size.y * 0.5))
		var lower := Rect2(Vector2(BOARD_RECT.position.x, BOARD_RECT.get_center().y), Vector2(BOARD_RECT.size.x, BOARD_RECT.size.y * 0.5))
		draw_rect(upper, Color(0.18, 0.72, 0.38, 0.12))
		draw_rect(lower, Color(0.35, 0.55, 1.0, 0.12))
		draw_line(Vector2(BOARD_RECT.position.x, BOARD_RECT.get_center().y), Vector2(BOARD_RECT.end.x, BOARD_RECT.get_center().y), Color(1, 1, 1, 0.38), 2.0)

	# 폭이 다른 옅은 판재 밴드와 비주기 곡선으로 절차적 원목을 표현한다.
	for band in 14:
		var band_y := BOARD_RECT.position.y + float(band) * BOARD_RECT.size.y / 14.0
		var tone := Color(0.44, 0.25, 0.09, 0.025 + float(band % 4) * 0.008)
		draw_rect(Rect2(BOARD_RECT.position.x + 3, band_y, BOARD_RECT.size.x - 6, BOARD_RECT.size.y / 14.0), tone)
	for grain in 26:
		var base_y := BOARD_RECT.position.y + 8.0 + float(grain) * 20.4
		var points := PackedVector2Array()
		for segment in 22:
			var ratio := float(segment) / 21.0
			var x := BOARD_RECT.position.x + 5.0 + ratio * (BOARD_RECT.size.x - 10.0)
			var wave := sin(ratio * 9.0 + grain * 1.73) * (1.0 + float(grain % 3) * 0.55)
			wave += sin(ratio * 21.0 + grain * 0.41) * 0.55
			points.append(Vector2(x, base_y + wave))
		draw_polyline(points, Color(0.30, 0.15, 0.055, 0.075), 1.15, true)
	# 작은 옹이 두 개는 반복 무늬를 끊되 격자보다 앞서지 않게 매우 은은하게 둔다.
	for knot in [Vector2(470, 174), Vector2(828, 548)]:
		draw_arc(knot, 9.0, 0.0, TAU, 28, Color(0.28, 0.13, 0.04, 0.09), 1.2)
		draw_arc(knot + Vector2(3, 0), 15.0, -1.1, 1.1, 18, Color(0.28, 0.13, 0.04, 0.055), 1.0)

	var spacing := GRID_RECT.size / float(GRID_COUNT - 1)
	var grid_color := Color(0.115, 0.075, 0.04, 0.88)
	for line in GRID_COUNT:
		var x := GRID_RECT.position.x + spacing.x * line
		var y := GRID_RECT.position.y + spacing.y * line
		draw_line(Vector2(GRID_RECT.position.x, y), Vector2(GRID_RECT.end.x, y), grid_color, 1.05, true)
		draw_line(Vector2(x, GRID_RECT.position.y), Vector2(x, GRID_RECT.end.y), grid_color, 1.05, true)
	for row in STAR_INDICES:
		for column in STAR_INDICES:
			draw_circle(grid_point(column, row), 3.15, Color(0.09, 0.055, 0.028, 0.96))

	# 위쪽 가장자리의 미세한 반사광으로 원목 코팅의 깊이를 더한다.
	draw_line(BOARD_RECT.position + Vector2(8, 5), Vector2(BOARD_RECT.end.x - 8, BOARD_RECT.position.y + 5), Color(1, 0.88, 0.62, 0.20), 1.4)
	for item in effect_lines:
		draw_line(item.from, item.to, item.color, float(item.width), true)
	if show_aim:
		var impulse := GameplayRules.shot_impulse(aim_origin, aim_pointer, aim_max_drag)
		var pull_end := aim_origin - impulse / GameplayRules.BALANCE.base_launch_impulse
		var direction := impulse.normalized()
		var displayed_max := GameplayRules.BALANCE.max_launch_impulse * (aim_max_drag / GameplayRules.BALANCE.drag_distance)
		var power := impulse.length() / displayed_max
		var guide_color := Color("ffe39a") if empowered_aim else active_color.lightened(0.18)
		draw_dashed_line(aim_origin, aim_origin + direction * (62.0 + power * 82.0) * guide_multiplier, guide_color, 3.0 if not empowered_aim else 4.0, 8.0)
		draw_line(aim_origin, pull_end, Color(1, 1, 1, 0.60), 2.0)
		draw_arc(aim_origin, 22.0 + power * 6.0, 0.0, TAU * power, 28, guide_color, 3.0)
	if placement_preview_visible:
		var preview_color := Color(0.25, 1.0, 0.42, 0.75) if placement_preview_valid else Color(1.0, 0.22, 0.18, 0.78)
		draw_circle(placement_preview_position, placement_preview_radius + 5.0, Color(preview_color, 0.18))
		draw_arc(placement_preview_position, placement_preview_radius + 5.0, 0.0, TAU, 48, preview_color, 3.0)

func _box(fill: Color, radius: int, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style
