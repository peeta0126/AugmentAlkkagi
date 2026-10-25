class_name FireballVisual
extends Node2D

@export_group("Travel")
@export_range(0.01, 2.0, 0.01) var travel_duration := 0.24
@export_range(0.0, 2.0, 0.01) var impact_fade_duration := 0.12

@onready var visual_root: Node2D = %VisualRoot
@onready var trail_particles: GPUParticles2D = %TrailParticles
@onready var animation_player: AnimationPlayer = %AnimationPlayer

var _travel_tween: Tween


func play(from: Vector2, to: Vector2) -> void:
	position = from
	rotation = (to - from).angle()
	trail_particles.emitting = true
	animation_player.play("pulse")
	_travel_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_travel_tween.tween_property(self, "position", to, travel_duration)
	_travel_tween.tween_callback(_on_arrived)


func _on_arrived() -> void:
	trail_particles.emitting = false
	var impact_tween := create_tween().set_parallel(true)
	impact_tween.tween_property(visual_root, "scale", Vector2(1.65, 1.65), impact_fade_duration)
	impact_tween.tween_property(visual_root, "modulate:a", 0.0, impact_fade_duration)
	impact_tween.chain().tween_callback(queue_free)
