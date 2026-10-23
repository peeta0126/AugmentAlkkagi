class_name SkillProjectile
extends Area2D

var projectile_color := Color.WHITE
var radius := 6.0

func setup(from: Vector2, to: Vector2, color: Color, travel_time: float = 0.24, size: float = 6.0) -> void:
	position = from
	projectile_color = color
	radius = size
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	collision.shape = circle
	add_child(collision)
	collision_layer = 4
	collision_mask = 1
	queue_redraw()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", to, travel_time)
	tween.tween_callback(queue_free)

func _draw() -> void:
	draw_circle(Vector2(3, 4), radius + 2, Color(0, 0, 0, 0.28))
	draw_circle(Vector2.ZERO, radius + 2, Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.22))
	draw_circle(Vector2.ZERO, radius, projectile_color)
	draw_circle(Vector2(-radius * 0.3, -radius * 0.35), maxf(1.0, radius * 0.28), Color(1, 1, 1, 0.72))
