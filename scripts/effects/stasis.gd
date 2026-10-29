class_name StasisVisual
extends Node2D
## 정지 상태: 돌 둘레에 검정 외곽선의 얼음 고리가 천천히 돌고, 위에 자물쇠 배지가 붙는다.

const LOCK := preload("res://assets/effects/ink_lock.png")

@export_range(0.05, 1.0, 0.01) var release_duration := 0.28

var _badge: Sprite2D
var _ring_angle := 0.0


func _ready() -> void:
	_badge = Sprite2D.new()
	_badge.texture = LOCK
	_badge.scale = Vector2.ONE * 0.26
	_badge.position = Vector2(13.0, -17.0)
	_badge.z_index = 2
	add_child(_badge)


func _process(delta: float) -> void:
	_ring_angle += delta * 0.8
	queue_redraw()


func _draw() -> void:
	var radius := 20.0
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(InkStyle.INK, 0.95), 6.0, true)
	for i in 8:
		var a0 := _ring_angle + TAU * i / 8.0
		draw_arc(Vector2.ZERO, radius, a0, a0 + TAU / 8.0 * 0.62, 8, Color("bfe6f6"), 3.2, true)


func release() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.45, 1.45), release_duration)
	tween.tween_property(self, "modulate:a", 0.0, release_duration)
	tween.chain().tween_callback(queue_free)
