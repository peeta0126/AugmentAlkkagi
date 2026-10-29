class_name BlizzardVisual
extends Node2D

const BLIZZARD_SHEET: Texture2D = preload("res://assets/effects/blizzard_sheet.png")
const BOARD_RECT := Rect2(Vector2(388.0, 96.0), Vector2(504.0, 540.0))
const GUST_REGIONS: Array[Rect2] = [
	Rect2(0, 0, 384, 330),
	Rect2(384, 0, 384, 330),
	Rect2(768, 0, 384, 330),
	Rect2(1152, 0, 384, 330),
]
const WIND_REGIONS: Array[Rect2] = [
	Rect2(690, 300, 420, 340),
	Rect2(1070, 300, 466, 340),
	Rect2(700, 640, 420, 200),
]
const SNOWFLAKE_REGION := Rect2(1370, 845, 166, 179)

@export_range(0.0, 3.0, 0.05) var fade_duration := 0.25
@export_range(0.1, 3.0, 0.05) var activation_duration := 0.9
@export_range(0.0, 1.0, 0.01) var wind_opacity := 0.2

@onready var snow_particles: GPUParticles2D = %SnowParticles

var _gust_frames: Array[AtlasTexture] = []
var _gusts: Array[Sprite2D] = []
var _gust_base_scales: Array[Vector2] = []
var _winds: Array[Sprite2D] = []
var _wind_origins: Array[Vector2] = []
var _ice_glints: Array[Line2D] = []
var _gust_elapsed := 0.0
var _wind_time := 0.0

func _ready() -> void:
	modulate.a = 0.0
	_create_gust_frames()
	_create_ambient_winds()
	_create_ice_glints()
	_create_activation_gusts()
	snow_particles.texture = _atlas(SNOWFLAKE_REGION)
	snow_particles.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, fade_duration)

func _process(delta: float) -> void:
	_wind_time += delta
	for index in range(_winds.size()):
		var wind := _winds[index]
		var phase := float(index) * 1.7
		wind.position = _wind_origins[index] + Vector2(sin(_wind_time * 0.75 + phase) * 30.0, cos(_wind_time * 0.55 + phase) * 12.0)
		wind.modulate.a = wind_opacity * (0.72 + 0.28 * sin(_wind_time * 1.25 + phase))
	for index in range(_ice_glints.size()):
		var pulse := 0.72 + 0.28 * sin(_wind_time * 1.1 + float(index) * 1.3)
		_ice_glints[index].modulate.a = pulse

	if not _gusts.is_empty():
		_gust_elapsed += delta
		var progress := clampf(_gust_elapsed / activation_duration, 0.0, 1.0)
		var frame_index := mini(int(_gust_elapsed / 0.12), _gust_frames.size() - 1)
		var pulse := sin(progress * PI)
		for index in range(_gusts.size()):
			var gust := _gusts[index]
			gust.texture = _gust_frames[frame_index]
			gust.scale = _gust_base_scales[index] * (0.78 + pulse * 0.3)
			gust.modulate.a = pulse
		if progress >= 1.0:
			for gust in _gusts:
				gust.queue_free()
			_gusts.clear()
			_gust_base_scales.clear()

func stop() -> void:
	snow_particles.emitting = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(queue_free)

func _create_gust_frames() -> void:
	for region in GUST_REGIONS:
		_gust_frames.append(_atlas(region))


func _create_ambient_winds() -> void:
	var center := BOARD_RECT.get_center()
	var positions := [center + Vector2(-80, -150), center + Vector2(110, 0), center + Vector2(-20, 165)]
	var sizes := [Vector2(330, 260), Vector2(350, 255), Vector2(355, 170)]
	for index in range(WIND_REGIONS.size()):
		var wind := Sprite2D.new()
		wind.name = "FlowingWind%d" % index
		wind.texture = _atlas(WIND_REGIONS[index])
		wind.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		wind.position = positions[index]
		wind.scale = sizes[index] / WIND_REGIONS[index].size
		wind.modulate = Color(0.88, 0.97, 1.0, wind_opacity)
		add_child(wind)
		_winds.append(wind)
		_wind_origins.append(wind.position)

func _create_ice_glints() -> void:
	var left := BOARD_RECT.position.x
	var top := BOARD_RECT.position.y
	var paths := [
		PackedVector2Array([Vector2(left + 34, top + 118), Vector2(left + 80, top + 124), Vector2(left + 122, top + 113)]),
		PackedVector2Array([Vector2(left + 306, top + 176), Vector2(left + 365, top + 184), Vector2(left + 430, top + 170)]),
		PackedVector2Array([Vector2(left + 62, top + 354), Vector2(left + 116, top + 346), Vector2(left + 174, top + 360)]),
		PackedVector2Array([Vector2(left + 282, top + 458), Vector2(left + 352, top + 449), Vector2(left + 465, top + 466)]),
	]
	for index in range(paths.size()):
		var glint := Line2D.new()
		glint.name = "IceSurfaceGlint%d" % index
		glint.points = paths[index]
		glint.width = 2.0 if index % 2 == 0 else 1.5
		glint.default_color = Color(0.9, 0.98, 1.0, 0.24)
		glint.begin_cap_mode = Line2D.LINE_CAP_ROUND
		glint.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(glint)
		_ice_glints.append(glint)

func _create_activation_gusts() -> void:
	var center_x := BOARD_RECT.get_center().x
	var positions := [
		Vector2(center_x, BOARD_RECT.position.y + 58.0),
		Vector2(center_x, BOARD_RECT.end.y - 58.0),
	]
	for index in range(positions.size()):
		var gust := Sprite2D.new()
		gust.name = "ActivationGust%d" % index
		gust.texture = _gust_frames[0]
		gust.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		gust.position = positions[index]
		gust.scale = Vector2(0.82, 0.72)
		gust.rotation = PI if index == 1 else 0.0
		gust.z_index = 2
		gust.modulate.a = 0.0
		add_child(gust)
		_gusts.append(gust)
		_gust_base_scales.append(gust.scale)

func _atlas(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = BLIZZARD_SHEET
	texture.region = region
	return texture
