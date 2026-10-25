class_name MergeVisual
extends Node2D

@export_range(0.05, 1.0, 0.01) var merge_duration := 0.4
@onready var incoming: Node2D = %IncomingStone


func play(from: Vector2, to: Vector2) -> void:
	position = to
	incoming.position = from - to
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(incoming, "position", Vector2(0, -7), merge_duration)
	tween.tween_property(incoming, "scale", Vector2(0.55, 0.55), merge_duration)
	tween.chain().tween_callback(queue_free)
