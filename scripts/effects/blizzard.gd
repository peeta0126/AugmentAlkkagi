class_name BlizzardVisual
extends Node2D

@export_range(0.0, 3.0, 0.05) var fade_duration := 0.25
@onready var snow_particles: GPUParticles2D = %SnowParticles


func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, fade_duration)


func stop() -> void:
	snow_particles.emitting = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(queue_free)
