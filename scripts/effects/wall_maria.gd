class_name WallMariaVisual
extends Node2D

@export_range(0.05, 1.0, 0.01) var deploy_duration := 0.3
@export var preview_valid_color := Color(0.45, 1.0, 0.62, 0.55)
@export var preview_invalid_color := Color(1.0, 0.25, 0.22, 0.62)


func _ready() -> void:
	scale.y = 0.1
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(self, "scale:y", 1.0, deploy_duration)

func show_preview(center: Vector2, wall_rotation: float, valid: bool) -> void:
	position = center
	rotation = wall_rotation
	modulate = preview_valid_color if valid else preview_invalid_color
	modulate.a = preview_valid_color.a if valid else preview_invalid_color.a
