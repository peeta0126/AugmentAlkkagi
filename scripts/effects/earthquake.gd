class_name EarthquakeVisual
extends Node2D

@export_range(0.1, 1.0, 0.05) var pulse_speed := 0.35
@onready var cracks_root: Node2D = %Cracks
@onready var crack_template: Line2D = %CrackTemplate
var elapsed := 0.0


func configure(data: Dictionary) -> void:
	for child in cracks_root.get_children():
		if child != crack_template:
			child.queue_free()
	crack_template.visible = false
	var width := float(data.get("width", 18.0))
	for crack: Dictionary in data.get("cracks", []):
		var line := crack_template.duplicate() as Line2D
		line.visible = true
		line.width = width
		line.points = PackedVector2Array([crack.from, crack.to])
		(line.get_node("HotCore") as Line2D).points = line.points
		cracks_root.add_child(line)


func _process(delta: float) -> void:
	elapsed += delta
	cracks_root.modulate.a = 0.78 + sin(elapsed / pulse_speed) * 0.18
