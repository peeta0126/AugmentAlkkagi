class_name StealthVisual
extends Node2D

@export_range(0.0, 4.0, 0.1) var swirl_speed := 1.2


func _process(delta: float) -> void:
	rotation += delta * swirl_speed
