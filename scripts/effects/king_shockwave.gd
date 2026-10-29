class_name KingShockwaveVisual
extends Node2D
## 왕의 충격파: 검정 테두리를 두른 주황·크림 고리가 번져 나가며 가운데에서 폭발이 터진다.

const BURST := preload("res://assets/ui/burst.png")

@export_range(0.05, 1.0, 0.01) var duration := 0.42

var _radius := 40.0
var _alpha := 1.0
var _burst: Sprite2D


func play(from: Vector2, to: Vector2) -> void:
	position = from.lerp(to, 0.5)
	var target := maxf(from.distance_to(to) * 0.5, 30.0)
	_burst = Sprite2D.new()
	_burst.texture = BURST
	_burst.scale = Vector2.ONE * minf(target / 150.0, 0.8) * 0.4
	add_child(_burst)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "_radius", target * 1.35, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_alpha", 0.0, duration).set_delay(duration * 0.35)
	tween.tween_property(_burst, "scale", _burst.scale * 1.7, duration * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_burst, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.3)
	tween.chain().tween_callback(queue_free)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var ink := Color(InkStyle.INK, _alpha)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 72, ink, 16.0, true)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 72, Color(InkStyle.ORANGE, _alpha), 9.0, true)
	draw_arc(Vector2.ZERO, _radius - 2.0, 0.0, TAU, 72, Color(InkStyle.CREAM, _alpha), 3.0, true)
