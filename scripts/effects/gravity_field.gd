class_name GravityFieldVisual
extends Node2D

@export var preview_radius := 125.0
@export_range(0.0, 5.0, 0.1) var rotation_speed := 0.8
@onready var field_shape: Node2D = %FieldShape


func configure(data: Dictionary) -> void:
	position = data.get("position", Vector2.ZERO)
	var radius := float(data.get("radius", preview_radius))
	field_shape.scale = Vector2.ONE * radius / maxf(preview_radius, 1.0)


