class_name TrainVisual
extends Node2D

@export_range(0.1, 3.0, 0.05) var travel_duration := 1.15
@onready var train_body: Node2D = %TrainBody
@onready var route: Line2D = %Route


func play(from: Vector2, to: Vector2) -> void:
	train_body.visible = true
	position = from
	rotation = (to - from).angle()
	var distance := from.distance_to(to)
	route.points = PackedVector2Array([Vector2.ZERO, Vector2(distance, 0)])
	train_body.position.x = -70.0
	var tween := create_tween().set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(train_body, "position:x", distance + 70.0, travel_duration)
	tween.tween_callback(queue_free)

func show_warning(from: Vector2, to: Vector2) -> void:
	position = from
	rotation = (to - from).angle()
	train_body.visible = false
	route.points = PackedVector2Array([Vector2.ZERO, Vector2(from.distance_to(to), 0.0)])
