class_name SonicBoomVisual
extends Node2D

@export_range(0.05, 1.0, 0.01) var shockwave_duration := 0.32
@onready var shockwave: Line2D = %Shockwave


func _ready() -> void:
	shockwave.default_color = Color(InkStyle.ORANGE, 0.95)
	shockwave.width = 5.0
	for line in $SpeedLines.get_children():
		(line as Line2D).default_color = Color(InkStyle.CREAM, 0.85)
		(line as Line2D).width = 3.0
	shockwave.scale = Vector2(0.25, 0.25)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(shockwave, "scale", Vector2(1.7, 1.7), shockwave_duration)
	tween.tween_property(shockwave, "modulate:a", 0.0, shockwave_duration)
