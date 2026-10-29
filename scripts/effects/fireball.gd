class_name FireballVisual
extends Node2D

@export_group("Travel")
@export_range(0.01, 2.0, 0.01) var travel_duration := 0.24
@export_range(0.0, 2.0, 0.01) var impact_fade_duration := 0.12

@onready var visual_root: Node2D = %VisualRoot
@onready var trail_particles: GPUParticles2D = %TrailParticles
@onready var animation_player: AnimationPlayer = %AnimationPlayer

var _travel_tween: Tween


func _ready() -> void:
	# 화염구 머리를 메인 화면 충돌 장면 같은 주황 폭발 그림으로 바꾼다.
	visual_root.visible = false
	var head := Sprite2D.new()
	head.name = "InkHead"
	head.texture = InkStyle.BURST_TEXTURE
	head.scale = Vector2.ONE * 0.05
	add_child(head)
	var spin := create_tween().set_loops()
	spin.tween_property(head, "rotation", TAU, 0.5).from(0.0)


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
	var head := get_node_or_null("InkHead") as Sprite2D
	var impact_tween := create_tween().set_parallel(true)
	if head:
		impact_tween.tween_property(head, "scale", Vector2.ONE * 0.13, impact_fade_duration + 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		impact_tween.tween_property(head, "modulate:a", 0.0, impact_fade_duration + 0.06)
	impact_tween.tween_property(visual_root, "modulate:a", 0.0, impact_fade_duration)
	impact_tween.chain().tween_callback(queue_free)
