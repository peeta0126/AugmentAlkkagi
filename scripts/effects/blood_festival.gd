class_name BloodFestivalVisual
extends Node2D
## 피의 축제 연출: 핏빛 붓 베기가 한 번 그어지며 핏방울이 튀고, "한 번 더!"가 떠오른다. 손으로 칠한 그림 시트를 쓴다.

const SHEET: Texture2D = preload("res://assets/effects/blood_sheet.png")

@export_range(0.1, 2.0, 0.05) var duration := 0.9
@export_range(0.03, 0.3, 0.01) var frame_time := 0.08


func play(from: Vector2, to: Vector2) -> void:
	position = from.lerp(to, 0.5)
	z_index = 20
	var slash := Sprite2D.new()
	slash.texture = SHEET
	slash.hframes = 4
	slash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	slash.scale = Vector2.ONE * 0.8
	add_child(slash)

	var notice := Label.new()
	notice.text = "한 번 더!"
	notice.size = Vector2(180.0, 44.0)
	notice.position = Vector2(-90.0, -64.0)
	notice.pivot_offset = notice.size * 0.5
	notice.rotation_degrees = -6.0
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.scale = Vector2(0.4, 0.4)
	notice.modulate.a = 0.0
	InkStyle.brush_label(notice, 30, InkStyle.CREAM, 10)
	add_child(notice)

	var tween := create_tween()
	for i in 4:
		tween.tween_callback(func(): slash.frame = i)
		tween.tween_interval(frame_time)
	var text_tween := create_tween().set_parallel(true)
	text_tween.tween_property(notice, "modulate:a", 1.0, 0.08).set_delay(0.1)
	text_tween.tween_property(notice, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1)
	text_tween.tween_property(notice, "position:y", -88.0, duration)
	text_tween.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(duration * 0.7)
	text_tween.chain().tween_callback(queue_free)
