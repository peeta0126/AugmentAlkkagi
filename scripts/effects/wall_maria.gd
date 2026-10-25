class_name WallMariaVisual
extends Node2D

@export_range(0.05, 1.0, 0.01) var deploy_duration := 0.3


func _ready() -> void:
	scale.y = 0.1
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(self, "scale:y", 1.0, deploy_duration)
