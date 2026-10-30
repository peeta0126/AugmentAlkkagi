class_name StealthVisual
extends Node2D
## 은신: 돌이 안개로 번져 사라지고(처음 한 번), 숨어 있는 동안엔 옅은 안개 고리가 천천히 돈다. 손으로 칠한 그림 시트를 쓴다.

const SHEET: Texture2D = preload("res://assets/effects/stealth_sheet.png")
const VANISH_FRAME_TIME := 0.1

var _mist: Sprite2D
var _time := 0.0


func _ready() -> void:
	var radius := 13.3
	var piece := get_parent() as AlkkagiPiece
	if piece != null:
		radius = piece.visual_radius
	z_index = 8
	# 사라지는 순간: 안개가 번지며 돌 모양이 흐려진다.
	var vanish := _sprite(0)
	vanish.scale = Vector2.ONE * (radius * 3.4 / 70.0)
	var tween := create_tween()
	for i in 4:
		tween.tween_callback(func(): vanish.frame = i)
		tween.tween_interval(VANISH_FRAME_TIME)
	tween.tween_callback(vanish.queue_free)
	# 숨어 있는 동안: 옅은 안개 고리
	_mist = _sprite(1)
	_mist.scale = Vector2.ONE * (radius * 1.6 / 34.0)
	_mist.modulate.a = 0.0
	tween.parallel().tween_property(_mist, "modulate:a", 0.8, 0.5).set_delay(0.3)


func _sprite(row: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = SHEET
	sprite.hframes = 4
	sprite.vframes = 2
	sprite.frame = row * 4
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	return sprite


func _process(delta: float) -> void:
	_time += delta
	if is_instance_valid(_mist):
		_mist.frame = 4 + int(_time * 4.0) % 4
		_mist.rotation = _time * 0.5
