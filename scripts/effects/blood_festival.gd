class_name BloodFestivalVisual
extends Node2D
## 피의 축제 연출: 핏빛 붓 베기가 휙 그어지고 "한 번 더!"가 튀어 오른다.

const SLASH := preload("res://assets/effects/blood_slash.png")
const BURST := preload("res://assets/ui/burst.png")

@export_range(0.1, 2.0, 0.05) var duration := 0.9


func play(from: Vector2, to: Vector2) -> void:
	position = from.lerp(to, 0.5)
	var length := maxf(from.distance_to(to), 60.0)
	var angle := (to - from).angle()

	var burst := Sprite2D.new()
	burst.texture = BURST
	burst.scale = Vector2.ONE * 0.12
	burst.modulate = Color(1, 1, 1, 0.95)
	add_child(burst)

	var slash := Sprite2D.new()
	slash.texture = SLASH
	slash.rotation = angle
	slash.scale = Vector2(length / SLASH.get_width() * 1.15, 0.2)
	slash.modulate.a = 0.0
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

	var tween := create_tween().set_parallel(true)
	tween.tween_property(burst, "scale", Vector2.ONE * 0.5, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "modulate:a", 0.0, 0.3).set_delay(0.18)
	tween.tween_property(slash, "modulate:a", 1.0, 0.05)
	tween.tween_property(slash, "scale:y", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(notice, "modulate:a", 1.0, 0.08)
	tween.tween_property(notice, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(notice, "position:y", -88.0, duration)
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(duration * 0.7)
	tween.chain().tween_callback(queue_free)
