class_name TrainVisual
extends Node2D
## 칙칙폭폭 연출: 먼저 철도와 위험 구간이 깔리고(예고), 위에서 내려다본 증기기관차가 연기를 뿜으며 지나간다.

const LOCO := preload("res://assets/effects/painted_train.png")
const PUFF := preload("res://assets/effects/smoke_puff.png")
const LOCO_SCALE := 0.4
const LANE_HALF := 38.0
const TIE_GAP := 20.0

enum Mode { NONE, WARNING, PASSING }

@export_range(0.1, 3.0, 0.05) var travel_duration := 1.15

var train_body: Sprite2D
var _mode := Mode.NONE
var _length := 504.0
var _time := 0.0
var _track_alpha := 0.0
var _puff_timer := 0.0


func _ready() -> void:
	train_body = Sprite2D.new()
	train_body.name = "TrainBody"
	train_body.texture = LOCO
	train_body.scale = Vector2.ONE * LOCO_SCALE
	train_body.offset = Vector2.ZERO  # 위에서 내려다본 그림이라 어느 방향으로 달려도 자연스럽다
	train_body.visible = false
	train_body.z_index = 1
	add_child(train_body)


func play(from: Vector2, to: Vector2) -> void:
	_set_path(from, to)
	_mode = Mode.PASSING
	create_tween().tween_property(self, "_track_alpha", 1.0, 0.12)
	train_body.visible = true
	train_body.position = Vector2(-140.0, 0.0)
	var tween := create_tween().set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(train_body, "position:x", _length + 140.0, travel_duration)
	tween.tween_property(self, "_track_alpha", 0.0, 0.3)
	tween.tween_callback(queue_free)


func show_warning(from: Vector2, to: Vector2) -> void:
	_set_path(from, to)
	if _mode != Mode.WARNING:
		_track_alpha = 0.0
		create_tween().tween_property(self, "_track_alpha", 1.0, 0.25)
	_mode = Mode.WARNING
	train_body.visible = false


func _set_path(from: Vector2, to: Vector2) -> void:
	position = from
	rotation = (to - from).angle()
	_length = from.distance_to(to)


func _process(delta: float) -> void:
	_time += delta
	if _mode == Mode.PASSING:
		_puff_timer -= delta
		if _puff_timer <= 0.0:
			_puff_timer = 0.07
			_spawn_puff()
	queue_redraw()


func _spawn_puff() -> void:
	var puff := Sprite2D.new()
	puff.texture = PUFF
	puff.position = train_body.position + Vector2(31.0, 0.0)  # 굴뚝 위치
	puff.scale = Vector2.ONE * 0.14
	puff.modulate = Color(1, 1, 1, 0.9)
	puff.z_index = 2
	add_child(puff)
	var drift := Vector2(randf_range(-80.0, -40.0), randf_range(-30.0, 30.0))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(puff, "position", puff.position + drift, 0.85).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "scale", Vector2.ONE * randf_range(0.36, 0.5), 0.85)
	tween.tween_property(puff, "modulate:a", 0.0, 0.85).set_delay(0.15)
	tween.chain().tween_callback(puff.queue_free)


func _draw() -> void:
	if _mode == Mode.NONE or _track_alpha <= 0.01:
		return
	var a := _track_alpha
	var pulse := 0.5 + 0.5 * sin(_time * 7.0)
	var ink := Color(InkStyle.INK, a)
	# 위험 구간: 예고 중에는 붉게 깜빡이고, 가장자리에 검정 점선 테두리가 있다.
	var danger := (0.16 + 0.12 * pulse) if _mode == Mode.WARNING else 0.12
	draw_rect(Rect2(0.0, -LANE_HALF, _length, LANE_HALF * 2.0), Color(0.88, 0.21, 0.1, danger * a))
	for side in [-1.0, 1.0]:
		var y: float = side * LANE_HALF
		var x := 0.0
		while x < _length:
			draw_line(Vector2(x, y), Vector2(minf(x + 14.0, _length), y), Color(0.88, 0.21, 0.1, 0.95 * a), 4.0)
			x += 26.0
	# 침목: 검정 외곽선 + 나무색
	var x := 6.0
	while x < _length:
		draw_rect(Rect2(x - 6.0, -17.0, 12.0, 34.0), ink)
		draw_rect(Rect2(x - 4.0, -15.0, 8.0, 30.0), Color(0.66, 0.4, 0.2, a))
		x += TIE_GAP
	# 레일: 검정 테두리 위에 크림색 레일
	for side in [-1.0, 1.0]:
		var yy: float = side * 10.0
		draw_line(Vector2(0.0, yy), Vector2(_length, yy), ink, 11.0)
		draw_line(Vector2(0.0, yy), Vector2(_length, yy), Color(InkStyle.CREAM, a), 5.0)
	# 진행 방향 화살표(예고 중에만 흐른다)
	if _mode == Mode.WARNING:
		var offset := fmod(_time * 110.0, 80.0)
		var cx := offset
		while cx < _length - 14.0:
			var c := Color(InkStyle.ORANGE, 0.9 * a)
			var pts := PackedVector2Array([Vector2(cx - 9.0, -13.0), Vector2(cx + 5.0, 0.0), Vector2(cx - 9.0, 13.0)])
			draw_colored_polygon(pts, c)
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), ink, 3.0)
			cx += 80.0
