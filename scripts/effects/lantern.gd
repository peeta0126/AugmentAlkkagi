class_name LanternVisual
extends Node2D

@export var preview_radius := 48.0
@onready var range_ring: Node2D = %RangeRing


func configure(data: Dictionary) -> void:
	position = data.get("position", Vector2.ZERO)
	var radius := float(data.get("radius", preview_radius))
	range_ring.scale = Vector2.ONE * radius / maxf(preview_radius, 1.0)


func _process(delta: float) -> void:
	%Flame.rotation += delta * 0.8
