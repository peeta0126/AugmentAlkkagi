class_name TemporaryWall
extends StaticBody2D

const WallMariaScene := preload("res://scenes/effects/wall_maria.tscn")

var wall_id := 0
var wall_size := GameplayRules.WALL_SIZE
var turns_left := 3
var cycle_based := false

func setup(center: Vector2, wall_rotation: float, duration: int, id: int = 0) -> void:
	wall_id = id
	position = center
	rotation = wall_rotation
	wall_size = GameplayRules.WALL_SIZE
	turns_left = duration
	var collision := CollisionShape2D.new()
	collision.name = "WallCollision"
	var rectangle := RectangleShape2D.new()
	rectangle.size = wall_size
	collision.shape = rectangle
	add_child(collision)
	var material := PhysicsMaterial.new()
	material.bounce = GameplayRules.WALL_BOUNCE
	material.friction = GameplayRules.WALL_FRICTION
	physics_material_override = material
	collision_layer = GameplayRules.WALL_COLLISION_LAYER
	collision_mask = 1
	var wall_visual := WallMariaScene.instantiate()
	wall_visual.name = "WallVisual"
	add_child(wall_visual)

func tick() -> bool:
	if cycle_based:
		return false
	turns_left -= 1
	return turns_left <= 0

