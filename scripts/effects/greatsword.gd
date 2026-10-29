class_name GreatswordVisual
extends Node2D

@export_range(0.05, 1.0, 0.01) var swing_duration := 0.42
@onready var sword: Node2D = %Sword
@onready var shockwave: Line2D = %Shockwave

const INK_SWORD := preload("res://assets/effects/ink_sword.png")


func _ready() -> void:
	# 기본 도형 칼 대신 잉크 스타일 대검 그림을 쓴다.
	for child in sword.get_children():
		(child as CanvasItem).visible = false
	var sprite := Sprite2D.new()
	sprite.texture = INK_SWORD
	sprite.scale = Vector2.ONE * 0.55
	sprite.position = Vector2(0.0, -34.0)
	sword.add_child(sprite)
	shockwave.default_color = Color(InkStyle.ORANGE, 0.95)
	shockwave.width = 10.0


func play(from: Vector2, to: Vector2) -> void:
	position = from.lerp(to, 0.5)
	var radius := from.distance_to(to) * 0.5
	scale = Vector2.ONE * maxf(radius / 120.0, 0.2)
	sword.rotation = -1.2
	shockwave.scale = Vector2(0.35, 0.35)
	shockwave.modulate.a = 0.9
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sword, "rotation", 1.15, swing_duration)
	tween.tween_property(shockwave, "scale", Vector2.ONE, swing_duration)
	tween.tween_property(shockwave, "modulate:a", 0.0, swing_duration)
	tween.chain().tween_callback(queue_free)
