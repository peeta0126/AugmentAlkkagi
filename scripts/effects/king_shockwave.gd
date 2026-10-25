class_name KingShockwaveVisual
extends Node2D

@export_range(0.05, 1.0, 0.01) var duration := 0.4
@onready var ring: Line2D = %ShockwaveRing

func play(from: Vector2, to: Vector2) -> void:
	position = from.lerp(to, 0.5)
	var radius := from.distance_to(to) * 0.5
	ring.scale = Vector2.ONE * maxf(radius / 78.0, 0.1)
	ring.modulate.a = 1.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", ring.scale * 1.35, duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(queue_free)
