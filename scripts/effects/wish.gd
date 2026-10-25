class_name WishVisual
extends Node2D

@onready var balls_root: Node2D = %DragonBalls
@onready var ball_template: Node2D = %DragonBallTemplate


func configure(data: Dictionary) -> void:
	for child in balls_root.get_children():
		if child != ball_template:
			child.queue_free()
	ball_template.visible = false
	for ball: Dictionary in data.get("balls", []):
		var visual := ball_template.duplicate() as Node2D
		visual.visible = true
		visual.position = ball.position
		(visual.get_node("NumberLabel") as Label).text = str(int(ball.number))
		balls_root.add_child(visual)
