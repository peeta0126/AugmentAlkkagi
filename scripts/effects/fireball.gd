class_name FireballVisual
extends Node2D

const SHEET: Texture2D = preload("res://assets/effects/wizard_sheet.png")

@export_group("Travel")
@export_range(0.01, 2.0, 0.01) var travel_duration := 0.24
@export_range(0.0, 2.0, 0.01) var impact_fade_duration := 0.12

@onready var visual_root: Node2D = %VisualRoot
@onready var trail_particles: GPUParticles2D = %TrailParticles
@onready var animation_player: AnimationPlayer = %AnimationPlayer

var _travel_tween: Tween


func _ready() -> void:
	# 화염구 머리를 마법사 시트의 빛나는 불덩이(꼬리 달린 4프레임)로 바꾼다.
	visual_root.visible = false
	trail_particles.visible = false
	var head := Sprite2D.new()
	head.name = "InkHead"
	head.texture = SHEET
	head.hframes = 4
	head.vframes = 2
	head.frame = 0
	head.scale = Vector2.ONE * 0.1  # 씬 루트가 5배라 실제로는 0.5배
	head.offset = Vector2(-62.0, 0.0)  # 시트 안에서 머리가 오른쪽으로 치우쳐 있어 중심을 머리에 맞춘다.
	head.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(head)
	var flicker := create_tween().set_loops()
	for i in 4:
		flicker.tween_callback(func(): head.frame = 0 + i)
		flicker.tween_interval(0.05)


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
	if head:
		head.visible = false
	var blast := Sprite2D.new()
	blast.texture = SHEET
	blast.hframes = 4
	blast.vframes = 2
	blast.frame = 4
	blast.rotation = -rotation  # 폭발은 방향과 상관없이 바로 서게 한다.
	blast.scale = Vector2.ONE * 0.1  # 루트 5배 → 실제 0.5배
	blast.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(blast)
	var tween := create_tween()
	for i in 4:
		tween.tween_callback(func(): blast.frame = 4 + i)
		tween.tween_interval(0.07)
	tween.tween_callback(queue_free)
