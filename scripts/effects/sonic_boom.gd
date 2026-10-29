class_name SonicBoomVisual
extends Node2D

const SONIC_SHEET: Texture2D = preload("res://assets/effects/sonic_boom_sheet.png")

@export_range(0.05, 1.0, 0.01) var frame_duration := 0.035
@export_range(0.1, 0.6, 0.01) var effect_scale := 0.24
@export_range(0.0, 1.0, 0.01) var repeat_interval := 0.0
@export_range(0.0, 1000.0, 1.0) var minimum_speed := 40.0
@export_range(0.02, 1.0, 0.01) var afterimage_interval := 0.055
@export_range(0.05, 1.0, 0.01) var afterimage_duration := 0.22
@export_range(0.0, 1.0, 0.01) var afterimage_opacity := 0.42

var _sprite: Sprite2D
var _frame_elapsed := 0.0
var _repeat_elapsed := 0.0
var _afterimage_elapsed := 0.0
var _frame_index := 0
var _playing := false

func _ready() -> void:
	show_behind_parent = true
	_sprite = Sprite2D.new()
	_sprite.name = "SonicProjectile"
	_sprite.texture = SONIC_SHEET
	_sprite.hframes = 4
	_sprite.vframes = 2
	_sprite.frame = 0
	_sprite.visible = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)

func _process(delta: float) -> void:
	var piece := get_parent() as AlkkagiPiece
	if not is_instance_valid(piece):
		return

	var velocity := piece.linear_velocity
	var speed := velocity.length()
	_repeat_elapsed = maxf(_repeat_elapsed - delta, 0.0)

	if speed < minimum_speed:
		_playing = false
		_sprite.visible = false
		_frame_index = 0
		_frame_elapsed = 0.0
		_afterimage_elapsed = 0.0
		return

	# The artwork points left, so rotate it to trail behind the stone's velocity.
	_sprite.rotation = velocity.angle() + PI
	_sprite.scale = Vector2.ONE * effect_scale * clampf(piece.visual_radius / 13.3, 0.75, 1.4)
	_sprite.position = -velocity.normalized() * piece.visual_radius * 0.25

	if not _playing and _repeat_elapsed <= 0.0:
		_playing = true
		_sprite.visible = true
		_sprite.frame = 0
		_frame_index = 0
		_frame_elapsed = 0.0
		_repeat_elapsed = repeat_interval

	if _playing:
		_afterimage_elapsed += delta
		if _afterimage_elapsed >= afterimage_interval:
			_afterimage_elapsed = 0.0
			_leave_afterimage(piece)
		_frame_elapsed += delta
		while _frame_elapsed >= frame_duration:
			_frame_elapsed -= frame_duration
			_frame_index += 1
			if _frame_index >= 8:
				_playing = false
				_sprite.visible = false
				break
			_sprite.frame = _frame_index

func _leave_afterimage(piece: AlkkagiPiece) -> void:
	var render_parent := piece.get_parent() as Node2D
	if not is_instance_valid(render_parent):
		return

	var afterimage := Sprite2D.new()
	afterimage.texture = _sprite.texture
	afterimage.hframes = _sprite.hframes
	afterimage.vframes = _sprite.vframes
	afterimage.frame = _sprite.frame
	afterimage.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	afterimage.modulate = Color(1.0, 1.0, 1.0, afterimage_opacity)
	render_parent.add_child(afterimage)
	render_parent.move_child(afterimage, piece.get_index())
	afterimage.global_transform = _sprite.global_transform

	var fade := afterimage.create_tween()
	fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_property(afterimage, "modulate:a", 0.0, afterimage_duration)
	fade.tween_callback(Callable(afterimage, "queue_free"))
