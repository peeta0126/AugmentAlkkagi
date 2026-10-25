class_name ConnectFourVisual
extends Node2D

@export_range(0.05, 1.0, 0.01) var reveal_duration := 0.35
@onready var glow_line: Line2D = %GlowLine
@onready var core_line: Line2D = %CoreLine

func configure(data: Dictionary) -> void:
	var from: Vector2 = data.get("from", Vector2.ZERO)
	var to: Vector2 = data.get("to", Vector2.RIGHT * 150.0)
	var color: Color = data.get("color", Color("ffd45e"))
	glow_line.points = PackedVector2Array([from, to])
	core_line.points = glow_line.points
	glow_line.default_color = Color(color.r, color.g, color.b, 0.35)
	core_line.default_color = color.lightened(0.35)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, reveal_duration)
