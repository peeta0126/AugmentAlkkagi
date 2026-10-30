class_name KingShockwaveVisual
extends Node2D
## 왕의 충격파: 왕이 적과 부딪히는 자리에서 만화 같은 충격선이 사방으로 뻗고 먹 테두리 금빛 고리가 퍼진다. 손으로 칠한 그림 시트를 쓴다.

const SHEET: Texture2D = preload("res://assets/effects/king_sheet.png")
const RING_RADIUS_IN_SHEET := 108.0  # 마지막 프레임에서 고리가 닿는 반지름(px)

@export_range(0.03, 0.3, 0.01) var frame_time := 0.085


func play(from: Vector2, to: Vector2) -> void:
	position = from.lerp(to, 0.5)
	z_index = 20
	var target := maxf(from.distance_to(to) * 0.5, 30.0)
	var sprite := Sprite2D.new()
	sprite.texture = SHEET
	sprite.hframes = 4
	sprite.vframes = 1
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2.ONE * (target * 1.35 / RING_RADIUS_IN_SHEET)
	add_child(sprite)
	var tween := create_tween()
	for i in 4:
		tween.tween_callback(func(): sprite.frame = i)
		tween.tween_interval(frame_time)
	tween.tween_callback(queue_free)
