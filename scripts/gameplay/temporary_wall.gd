class_name TemporaryWall
extends StaticBody2D

var wall_id := 0
var wall_size := GameplayRules.WALL_SIZE
var turns_left := 3

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
	queue_redraw()

func tick() -> bool:
	turns_left -= 1
	return turns_left <= 0

func _draw() -> void:
	draw_rect(Rect2(-wall_size * 0.5 - Vector2(3, 3), wall_size + Vector2(6, 6)), Color(0.16, 0.12, 0.10, 0.45), true)
	draw_rect(Rect2(-wall_size * 0.5, wall_size), Color("c9b08a"), true)
	draw_rect(Rect2(-wall_size * 0.5, wall_size), Color("5f4b37"), false, 2.0)
