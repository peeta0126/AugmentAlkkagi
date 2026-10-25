class_name GreatswordVisual
extends Node2D

@export_range(0.05, 1.0, 0.01) var swing_duration := 0.42
@onready var sword: Node2D = %Sword
@onready var shockwave: Line2D = %Shockwave


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
