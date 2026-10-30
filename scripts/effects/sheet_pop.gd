class_name SheetPopVisual
extends Node2D
## 그림 시트의 한 줄(4프레임)을 한 자리에서 한 번 재생하고 사라지는 연출.

const COLUMNS := 4


## sheet의 row번째 줄을 pos에서 재생한다. 스케일·회전·시작 지연을 줄 수 있다.
static func spawn(parent: Node, pos: Vector2, sheet: Texture2D, rows: int, row: int, size: float, rot: float = 0.0, frame_time: float = 0.07, delay: float = 0.0) -> SheetPopVisual:
	var pop := SheetPopVisual.new()
	pop.position = pos
	pop.rotation = rot
	pop.z_index = 15
	parent.add_child(pop)
	pop._play(sheet, rows, row, size, frame_time, delay)
	return pop


func _play(sheet: Texture2D, rows: int, row: int, size: float, frame_time: float, delay: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = sheet
	sprite.hframes = COLUMNS
	sprite.vframes = rows
	sprite.frame = row * COLUMNS
	sprite.scale = Vector2.ONE * size
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.visible = false
	add_child(sprite)
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(func(): sprite.visible = true)
	for i in COLUMNS:
		tween.tween_callback(func(): sprite.frame = row * COLUMNS + i)
		tween.tween_interval(frame_time)
	tween.tween_callback(queue_free)
