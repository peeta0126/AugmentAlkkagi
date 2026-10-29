class_name BlindVisual
extends Control

## 접근성: 실명 암막의 세기. 내 화면에서 보이는 정도만 바꾸고 게임 규칙은 그대로다.
const LEVELS := [
	{"name": "약하게", "radius": 40.0, "alpha": 0.82},
	{"name": "보통", "radius": 26.0, "alpha": 0.96},
	{"name": "강하게", "radius": 20.0, "alpha": 0.995},
]
const DEFAULT_LEVEL := 1
const SETTINGS_PATH := "user://settings.cfg"

@onready var board_veil: ColorRect = %BoardVeil
@onready var aim_guide: Line2D = %AimGuide

var veil_material: ShaderMaterial

static func load_level() -> int:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return DEFAULT_LEVEL
	return clampi(int(config.get_value("accessibility", "blind_level", DEFAULT_LEVEL)), 0, LEVELS.size() - 1)

static func save_level(level: int) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("accessibility", "blind_level", clampi(level, 0, LEVELS.size() - 1))
	config.save(SETTINGS_PATH)

func _ready() -> void:
	veil_material = board_veil.material as ShaderMaterial
	apply_level(load_level())

func apply_level(level: int) -> void:
	var settings: Dictionary = LEVELS[clampi(level, 0, LEVELS.size() - 1)]
	var color: Color = veil_material.get_shader_parameter("veil_color")
	color.a = float(settings.alpha)
	veil_material.set_shader_parameter("veil_color", color)
	veil_material.set_shader_parameter("sight_radius", float(settings.radius))

func update_view(centers: PackedVector2Array, board_size: Vector2, aim_from: Vector2, aim_to: Vector2, show_aim: bool) -> void:
	if veil_material == null:
		veil_material = board_veil.material as ShaderMaterial
	veil_material.set_shader_parameter("centers", centers)
	veil_material.set_shader_parameter("center_count", centers.size())
	veil_material.set_shader_parameter("board_size", board_size)
	aim_guide.visible = show_aim
	if show_aim:
		aim_guide.points = PackedVector2Array([aim_from, aim_to])
