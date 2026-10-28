@tool
class_name TankVisual
extends Node2D

const BLACK_TEXTURE := preload("res://assets/tank/tank_black.png")
const WHITE_TEXTURE := preload("res://assets/tank/tank_white.png")

# Edit these values on the Tank scene's root node in the Inspector.
@export_enum("Black:1", "White:2") var preview_owner_id := 1
@export_range(16.0, 160.0, 1.0) var base_display_width := 56.0:
	set(value):
		base_display_width = value
		_update_scale()
@export_range(0.25, 4.0, 0.05) var size_multiplier := 1.0:
	set(value):
		size_multiplier = value
		_update_scale()
@export_range(0.0, 30.0, 0.5) var turn_speed := 12.0
@export_range(0.0, 200.0, 1.0) var minimum_turn_speed := 30.0

@onready var sprite: Sprite2D = $Sprite
var stone_radius := 13.32
var visual_owner_id := 0

func _ready() -> void:
	_update_scale()

func configure(owner_id: int, radius: float) -> void:
	stone_radius = radius
	if not is_node_ready():
		await ready
	if not is_instance_valid(sprite):
		return
	visual_owner_id = owner_id
	sprite.texture = BLACK_TEXTURE if owner_id == 1 else WHITE_TEXTURE
	_update_scale()

func _update_scale() -> void:
	if not is_node_ready() or not is_instance_valid(sprite) or sprite.texture == null:
		return
	# The stone body fills the collision circle; tracks extend slightly beyond it.
	var displayed_width := base_display_width * size_multiplier * maxf(stone_radius, 16.65) / 16.65
	var width_scale := displayed_width / float(sprite.texture.get_width())
	var height_scale := displayed_width / float(sprite.texture.get_height())
	var owner_for_scale := visual_owner_id if visual_owner_id > 0 else preview_owner_id
	if owner_for_scale == 2:
		# Match the visible (non-transparent) artwork bounds to the black tank.
		width_scale *= (982.0 / 1312.0) / (1077.0 / 1254.0)
		height_scale *= (1071.0 / 1199.0) / (1151.0 / 1254.0)
	sprite.scale = Vector2(width_scale, height_scale)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var piece := get_parent() as RigidBody2D
	if piece == null or piece.linear_velocity.length() < minimum_turn_speed:
		return
	# The barrel points up in the source image, so add 90 degrees to velocity's angle.
	rotation = lerp_angle(rotation, piece.linear_velocity.angle() + PI * 0.5, clampf(turn_speed * delta, 0.0, 1.0))
