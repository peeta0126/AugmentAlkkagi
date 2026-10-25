class_name BlindVisual
extends Control

@onready var board_veil: ColorRect = %BoardVeil
@onready var aim_guide: Line2D = %AimGuide

var veil_material: ShaderMaterial

func _ready() -> void:
	veil_material = board_veil.material as ShaderMaterial

func update_view(centers: PackedVector2Array, board_size: Vector2, aim_from: Vector2, aim_to: Vector2, show_aim: bool) -> void:
	if veil_material == null:
		veil_material = board_veil.material as ShaderMaterial
	veil_material.set_shader_parameter("centers", centers)
	veil_material.set_shader_parameter("center_count", centers.size())
	veil_material.set_shader_parameter("board_size", board_size)
	aim_guide.visible = show_aim
	if show_aim:
		aim_guide.points = PackedVector2Array([aim_from, aim_to])
