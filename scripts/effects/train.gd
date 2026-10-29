class_name TrainVisual
extends Node2D
## 칙칙폭폭 연출: 경로에는 선로와 위험 구간이 먼저 깔리고(예고), 기차가 연기를 뿜으며 지나간다.

const LOCO := preload("res://assets/effects/train_loco.png")
const PUFF := preload("res://assets/effects/smoke_puff.png")
const LOCO_SCALE := 0.27
const LANE_HALF := 35.0
const TIE_GAP := 17.0

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
	train_body.visible = false
	train_body.z_index = 1
	add_child(train_body)


func play(from: Vector2, to: Vector2) -> void:
	_set_path(from, to)
	_mode = Mode.PASSING
	create_tween().tween_property(self, "_track_alpha", 1.0, 0.12)
	train_body.visible = true
	train_body.position = Vector2(-120.0, 0.0)
	var tween := create_tween().set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(train_body, "position:x", _length + 120.0, travel_duration)
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
			_puff_timer = 0.075
			_spawn_puff()
	queue_redraw()


func _spawn_puff() -> void:
	var puff := Sprite2D.new()
	puff.texture = PUFF
	puff.position = train_body.position + Vector2(36.0, -33.0)
	puff.scale = Vector2.ONE * 0.12
	puff.modulate = Color(1, 1, 1, 0.85)
	puff.z_index = 2
	add_child(puff)
	var drift := Vector2(randf_range(-46.0, -20.0), randf_range(-44.0, -26.0))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(puff, "position", puff.position + drift, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "scale", Vector2.ONE * randf_range(0.32, 0.46), 0.8)
	tween.tween_property(puff, "modulate:a", 0.0, 0.8).set_delay(0.15)
	tween.chain().tween_callback(puff.queue_free)


func _draw() -> void:
	if _mode == Mode.NONE or _track_alpha <= 0.01:
		return
	var a := _track_alpha
	# 위험 구간: 예고 중에는 숨 쉬듯 붉게 깜빡인다.
	var pulse := 0.5 + 0.5 * sin(_time * 7.0)
	var danger := (0.10 + 0.10 * pulse) if _mode == Mode.WARNING else 0.08
	draw_rect(Rect2(0.0, -LANE_HALF, _length, LANE_HALF * 2.0), Color(0.72, 0.16, 0.12, danger * a))
	for side in [-1.0, 1.0]:
		draw_line(Vector2(0.0, side * LANE_HALF), Vector2(_length, side * LANE_HALF), Color(0.72, 0.16, 0.12, (0.45 + 0.25 * pulse) * a), 2.0)
	# 침목과 레일
	var x := 0.0
	while x < _length:
		draw_rect(Rect2(x - 3.0, -15.0, 6.0, 30.0), Color(0.29, 0.20, 0.13, 0.85 * a))
		x += TIE_GAP
	for side in [-1.0, 1.0]:
		var y: float = side * 9.0
		draw_line(Vector2(0.0, y), Vector2(_length, y), Color(0.13, 0.09, 0.07, 0.9 * a), 5.0)
		draw_line(Vector2(0.0, y), Vector2(_length, y), Color(0.67, 0.64, 0.58, 0.95 * a), 2.6)
	# 진행 방향을 알려 주는 화살표(예고 중에만 흐른다)
	if _mode == Mode.WARNING:
		var offset := fmod(_time * 90.0, 70.0)
		var cx := offset
		while cx < _length - 12.0:
			var c := Color(0.86, 0.26, 0.2, (0.55 - 0.45 * cx / maxf(_length, 1.0)) * a)
			draw_line(Vector2(cx - 7.0, -11.0), Vector2(cx, 0.0), c, 3.0)
			draw_line(Vector2(cx - 7.0, 11.0), Vector2(cx, 0.0), c, 3.0)
			cx += 70.0
