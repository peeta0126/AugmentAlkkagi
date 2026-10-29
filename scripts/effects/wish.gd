class_name WishVisual
extends Node2D
## 소원 연출: 별 개수가 번호인 드래곤볼 그림이 보드 위에서 살짝 떠올랐다 가라앉는다.

const BALL_SCALE := 0.52

@onready var balls_root: Node2D = %DragonBalls


func configure(data: Dictionary) -> void:
	for child in balls_root.get_children():
		child.queue_free()
	for ball: Dictionary in data.get("balls", []):
		var number := clampi(int(ball.number), 1, 7)
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/effects/dragon_ball_%d.png" % number)
		sprite.position = ball.position
		sprite.scale = Vector2.ONE * BALL_SCALE
		balls_root.add_child(sprite)
		var bob := create_tween().set_loops()
		bob.tween_property(sprite, "scale", Vector2.ONE * BALL_SCALE * 1.08, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(randf() * 0.5)
		bob.tween_property(sprite, "scale", Vector2.ONE * BALL_SCALE, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
