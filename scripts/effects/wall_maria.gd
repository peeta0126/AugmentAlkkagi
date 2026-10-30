class_name WallMariaVisual
extends Node2D

@export_range(0.05, 1.0, 0.01) var deploy_duration := 0.3
@export var preview_valid_color := Color(0.45, 1.0, 0.62, 0.55)
@export var preview_invalid_color := Color(1.0, 0.25, 0.22, 0.62)


const SHADOW_OFFSET := Vector2(3.0, 5.0)
const BODY_OFFSET := Vector2.ZERO


## 위에서 본 평평한 그림이라 어느 방향이든 뒤집을 필요가 없다.
static func needs_flip(_wall_rotation: float) -> bool:
	return false


## 그림자는 벽을 돌려도 항상 같은 쪽(오른쪽 아래)으로 떨어진다.
func _update_shadow() -> void:
	var shadow := get_node_or_null("Shadow") as Node2D
	if shadow != null:
		shadow.position = BODY_OFFSET + SHADOW_OFFSET.rotated(-global_rotation)


func _ready() -> void:
	var body := get_node_or_null("WallBody") as Node2D
	if body != null:
		body.position = BODY_OFFSET
	_update_shadow()
	scale.y = 0.1
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(self, "scale:y", 1.0, deploy_duration)

func show_preview(center: Vector2, wall_rotation: float, valid: bool) -> void:
	position = center
	rotation = wall_rotation + (PI if needs_flip(wall_rotation) else 0.0)
	_update_shadow()
	modulate = preview_valid_color if valid else preview_invalid_color
	modulate.a = preview_valid_color.a if valid else preview_invalid_color.a
