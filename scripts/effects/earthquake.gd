class_name EarthquakeVisual
extends Node2D

@export_range(0.1, 1.0, 0.05) var pulse_speed := 0.35
@onready var cracks_root: Node2D = %Cracks
@onready var crack_template: Line2D = %CrackTemplate
var elapsed := 0.0


func configure(data: Dictionary) -> void:
	for child in cracks_root.get_children():
		if child != crack_template:
			cracks_root.remove_child(child)
			child.queue_free()
	crack_template.visible = false
	for crack: Dictionary in data.get("cracks", []):
		var line := crack_template.duplicate() as Line2D
		var from: Vector2 = crack.get("from", Vector2.ZERO)
		var to: Vector2 = crack.get("to", Vector2.ZERO)
		var segment := to - from
		var template_length := 1.0
		if line.points.size() >= 2:
			template_length = maxf(line.points[0].distance_to(line.points[line.points.size() - 1]), 1.0)
		line.position = from.lerp(to, 0.5)
		line.rotation = segment.angle()
		line.scale = Vector2.ONE * (segment.length() / template_length)
		# Keep the designer-authored CrackSprite intact. Collision continues to
		# use the authoritative from/to segment stored by EarthquakeAugmentEffect.
		line.width = 0.0
		line.visible = true
		var hot_core := line.get_node_or_null("HotCore") as Line2D
		if hot_core != null:
			hot_core.visible = false
		cracks_root.add_child(line)


func _process(delta: float) -> void:
	elapsed += delta
	cracks_root.modulate.a = 0.78 + sin(elapsed / pulse_speed) * 0.18
