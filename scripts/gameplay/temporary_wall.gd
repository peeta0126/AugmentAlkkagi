class_name TemporaryWall
extends StaticBody2D

var wall_size := Vector2(150, 12)
var turns_left := 3

func setup(center: Vector2, horizontal: bool, duration: int) -> void:
	position = center
	wall_size = Vector2(150, 12) if horizontal else Vector2(12, 150)
	turns_left = duration
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = wall_size
	collision.shape = rectangle
	add_child(collision)
	var material := PhysicsMaterial.new()
	material.bounce = 0.88
	material.friction = 0.05
	physics_material_override = material
	collision_layer = 2
	collision_mask = 1
	queue_redraw()

func tick() -> bool:
	turns_left -= 1
	return turns_left <= 0

func _draw() -> void:
	draw_rect(Rect2(-wall_size * 0.5 - Vector2(3, 3), wall_size + Vector2(6, 6)), Color(0.16, 0.12, 0.10, 0.45), true)
	draw_rect(Rect2(-wall_size * 0.5, wall_size), Color("c9b08a"), true)
	draw_rect(Rect2(-wall_size * 0.5, wall_size), Color("5f4b37"), false, 2.0)
