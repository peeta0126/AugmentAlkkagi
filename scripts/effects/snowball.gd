class_name SnowballVisual
extends Node2D

@export_group("Timing")
@export_range(0.01, 2.0, 0.01) var travel_duration := 0.24
@export_range(0.01, 1.0, 0.01) var impact_duration := 0.28

@onready var projectile: Node2D = %Projectile
@onready var trail_particles: GPUParticles2D = %TrailParticles
@onready var impact_particles: GPUParticles2D = %ImpactParticles
@onready var aim_guide: Node2D = %AimGuide
@onready var trajectory: Line2D = %Trajectory
@onready var target_ring: Line2D = %TargetRing


func play(from: Vector2, to: Vector2) -> void:
	position = from
	rotation = (to - from).angle()
	trail_particles.emitting = true
	var travel := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	travel.tween_property(self, "position", to, travel_duration)
	travel.tween_callback(_impact)

func show_preview(from: Vector2, target: Vector2, max_range: float) -> void:
	position = from
	rotation = 0.0
	projectile.visible = false
	aim_guide.visible = true
	var endpoint := from + from.direction_to(target) * minf(from.distance_to(target), max_range)
	trajectory.points = PackedVector2Array([Vector2.ZERO, endpoint - from])
	target_ring.position = endpoint - from

func begin_runtime(at: Vector2, direction: Vector2, radius: float) -> void:
	aim_guide.visible = false
	projectile.visible = true
	projectile.scale = Vector2.ONE * radius / 7.0
	trail_particles.emitting = true
	update_runtime(at, direction)

func update_runtime(at: Vector2, direction: Vector2) -> void:
	position = at
	rotation = direction.angle()

func finish(hit: bool) -> void:
	trail_particles.emitting = false
	projectile.visible = false
	aim_guide.visible = false
	if hit:
		impact_particles.emitting = true
		await get_tree().create_timer(impact_duration).timeout
		queue_free()
	else:
		var fade := create_tween()
		fade.tween_property(self, "modulate:a", 0.0, 0.12)
		fade.tween_callback(queue_free)


func _impact() -> void:
	finish(true)
