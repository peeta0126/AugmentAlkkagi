class_name StasisVisual
extends Node2D

@export_range(0.05, 1.0, 0.01) var release_duration := 0.28


func _process(delta: float) -> void:
	rotation += delta * 0.7


func release() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.45, 1.45), release_duration)
	tween.tween_property(self, "modulate:a", 0.0, release_duration)
	tween.chain().tween_callback(queue_free)
