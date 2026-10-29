class_name KingVisual
extends Node2D

@onready var aura: Node2D = %GoldenAura

func _ready() -> void:
	scale = Vector2(0.4, 0.4)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(self, "scale", Vector2.ONE, 0.45)

func set_shockwave_available(available: bool) -> void:
	aura.modulate.a = 0.9 if available else 0.35

func _process(delta: float) -> void:
	aura.rotation += delta * 0.45
	queue_redraw()


func _draw() -> void:
	# 왕의 충격파를 쓸 수 있으면 주황 잉크 고리가 돌고, 쓴 뒤에는 옅어진다.
	var alpha := aura.modulate.a
	draw_arc(Vector2.ZERO, 27.0, 0.0, TAU, 40, Color(InkStyle.INK, alpha), 7.0, true)
	for i in 10:
		var a0 := aura.rotation + TAU * i / 10.0
		draw_arc(Vector2.ZERO, 27.0, a0, a0 + TAU / 10.0 * 0.6, 8, Color(InkStyle.ORANGE, alpha), 3.6, true)
