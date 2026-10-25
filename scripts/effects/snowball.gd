class_name SnowballVisual
extends Node2D

@export_group("Timing")
@export_range(0.01, 2.0, 0.01) var travel_duration := 0.24
@export_range(0.01, 1.0, 0.01) var impact_duration := 0.28

@onready var projectile: Node2D = %Projectile
@onready var trail_particles: GPUParticles2D = %TrailParticles
@onready var impact_particles: GPUParticles2D = %ImpactParticles


func play(from: Vector2, to: Vector2) -> void:
	position = from
	rotation = (to - from).angle()
	trail_particles.emitting = true
	var travel := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	travel.tween_property(self, "position", to, travel_duration)
	travel.tween_callback(_impact)


func _impact() -> void:
	trail_particles.emitting = false
	projectile.visible = false
	impact_particles.emitting = true
	await get_tree().create_timer(impact_duration).timeout
	queue_free()
