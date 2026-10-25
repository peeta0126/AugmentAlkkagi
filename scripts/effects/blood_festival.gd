class_name BloodFestivalVisual
extends Node2D

@export_range(0.1, 2.0, 0.05) var duration := 0.85
@onready var slash: Line2D = %BloodSlash
@onready var notice: Label = %BonusTurnNotice


func play(from: Vector2, to: Vector2) -> void:
	position = from.lerp(to, 0.5)
	slash.points = PackedVector2Array([from - position, to - position])
	notice.position = Vector2(-48, -45)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(slash, "width", 18.0, duration * 0.35)
	tween.tween_property(notice, "position:y", -62.0, duration)
	tween.tween_property(self, "modulate:a", 0.0, duration).set_delay(duration * 0.45)
	tween.chain().tween_callback(queue_free)
