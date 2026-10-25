class_name DodgeVisual
extends Node2D

@export_range(0.05, 1.0, 0.01) var duration := 0.4
@onready var path: Line2D = %MovementPath
@onready var ghost: Node2D = %Ghost
@onready var success: Node2D = %SuccessBurst


func play(from: Vector2, to: Vector2) -> void:
	position = from
	path.points = PackedVector2Array([Vector2.ZERO, to - from])
	ghost.position = Vector2.ZERO
	success.position = to - from
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ghost, "position", to - from, duration)
	tween.tween_property(ghost, "modulate:a", 0.0, duration)
	tween.tween_property(success, "scale", Vector2(1.5, 1.5), duration)
	tween.tween_property(path, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(queue_free)
