class_name DodgeVisual
extends Node2D
## 느려 회피: 손으로 칠한 바람 줄기가 옆으로 스치고, 있던 자리엔 돌 모양 잔상이, 도착한 자리엔 흙먼지가 인다.

const SHEET: Texture2D = preload("res://assets/effects/dodge_sheet.png")
const FRAME_TIME := 0.07
const HEAD_OFFSET := 84.0  # 시트 안에서 바람 줄기 머리가 중심에서 오른쪽으로 떨어진 거리(px)

@export_range(0.1, 1.5, 0.01) var effect_scale := 0.55


func play(from: Vector2, to: Vector2) -> void:
	position = from
	z_index = 20
	var delta := to - from
	var dir := delta.normalized() if delta.length() > 0.01 else Vector2.RIGHT
	_afterimages(delta, dir)
	var whoosh := _sprite()
	whoosh.position = delta - dir * HEAD_OFFSET * effect_scale
	whoosh.rotation = dir.angle()
	whoosh.scale = Vector2.ONE * effect_scale
	_play_frames(whoosh, 0, 0.0)
	var dust := _sprite()
	dust.position = delta
	dust.scale = Vector2.ONE * effect_scale * 0.7
	_play_frames(dust, 1, FRAME_TIME * 1.5)
	var tween := create_tween()
	tween.tween_interval(FRAME_TIME * 10.0)
	tween.tween_callback(queue_free)


func _sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = SHEET
	sprite.hframes = 4
	sprite.vframes = 2
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.visible = false
	add_child(sprite)
	return sprite


func _play_frames(sprite: Sprite2D, row: int, delay: float) -> void:
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(func(): sprite.visible = true)
	for i in 4:
		tween.tween_callback(func(): sprite.frame = row * 4 + i)
		tween.tween_interval(FRAME_TIME)
	tween.tween_callback(func(): sprite.visible = false)


func _afterimages(delta: Vector2, dir: Vector2) -> void:
	# 지나온 길에 돌 모양 잔상이 남았다가 먹물이 번지듯 사라진다(잉크 테두리의 반투명 돌).
	for i in 3:
		var ghost := Node2D.new()
		ghost.position = delta * (float(i) / 3.0)
		add_child(ghost)
		var body := Polygon2D.new()
		var points := PackedVector2Array()
		for s in 24:
			points.append(Vector2.RIGHT.rotated(TAU * float(s) / 24.0) * 13.0)
		body.polygon = points
		body.color = Color("e9f3fa")
		ghost.add_child(body)
		var outline := Line2D.new()
		outline.points = points + PackedVector2Array([points[0]])
		outline.width = 2.5
		outline.default_color = Color("1c1512")
		ghost.add_child(outline)
		ghost.modulate.a = 0.55 - 0.12 * float(i)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(ghost, "modulate:a", 0.0, 0.3 + 0.06 * float(i))
		tween.tween_property(ghost, "scale", Vector2(1.25, 0.8) if absf(dir.x) > absf(dir.y) else Vector2(0.8, 1.25), 0.3)
