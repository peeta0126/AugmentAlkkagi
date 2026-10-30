class_name MergeVisual
extends Node2D
## 합체. 날아갈 때(play): 합쳐질 돌이 금빛 꼬리를 끌며 빨려 들어가고, 도착 자리에서 손으로 칠한 금빛 소용돌이가 감기다가 터진다.
## 합쳐진 뒤(돌의 자식으로 상주): 금빛 테두리가 숨 쉬고, 삼킨 돌 수만큼 작은 금돌이 테두리를 돈다.

const SHEET: Texture2D = preload("res://assets/effects/merge_sheet.png")
const GOLD := Color("e5b56d")
const FRAME_TIME := 0.06

@export_range(0.1, 1.5, 0.01) var merge_duration := 0.45

var _flying := false
var _t := 0.0
var _from_local := Vector2.ZERO
var _time := 0.0


func play(from: Vector2, to: Vector2) -> void:
	_flying = true
	position = to
	z_index = 20
	_from_local = from - to
	var vortex := _sheet_sprite(0)
	vortex.scale = Vector2.ONE * 0.5
	vortex.modulate.a = 0.0
	var impact := _sheet_sprite(1)
	impact.scale = Vector2.ONE * 0.5
	impact.visible = false
	var tween := create_tween()
	tween.tween_property(self, "_t", 1.0, merge_duration)
	# 소용돌이는 스프라이트를 돌리지 않고, 그려 둔 프레임 순서대로 팔이 안으로 말려 들어가게 한다.
	tween.parallel().tween_property(vortex, "modulate:a", 1.0, merge_duration * 0.25)
	tween.parallel().tween_property(vortex, "scale", Vector2.ONE * 0.4, merge_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_method(func(f: float): vortex.frame = mini(int(f * 4.0), 3), 0.0, 0.999, merge_duration)
	tween.tween_callback(func(): vortex.visible = false; impact.visible = true)
	for i in 4:
		tween.tween_callback(func(): impact.frame = 4 + i)
		tween.tween_interval(FRAME_TIME)
	tween.tween_callback(queue_free)


func _sheet_sprite(row: int) -> Sprite2D:
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
	queue_redraw()


func _ink_disc(center: Vector2, radius: float, alpha: float) -> void:
	draw_circle(center, radius + 3.0, Color(InkStyle.INK, alpha))
	draw_circle(center, radius, Color(GOLD, alpha))
	draw_circle(center + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.28, Color(InkStyle.CREAM, alpha * 0.85))


func _draw() -> void:
	if _flying:
		_draw_flight()
	else:
		_draw_resident()


func _draw_flight() -> void:
	if _t >= 1.0:
		return
	var eased := _t * _t * _t  # 점점 빨려 들어간다
	var pos := _from_local * (1.0 - eased)
	var dir := (-_from_local).normalized()
	var side := dir.orthogonal()
	var tail := pos - dir * minf(_from_local.length() * 0.45 * (1.0 - eased * 0.4), 90.0)
	for layer in 2:
		var half_w := 9.0 if layer == 1 else 14.0
		var color := Color(GOLD, 0.85) if layer == 1 else Color(InkStyle.INK, 0.9)
		draw_colored_polygon(PackedVector2Array([tail, pos + side * half_w, pos - side * half_w]), color)
	_ink_disc(pos, lerpf(13.0, 8.0, eased), 1.0)


func _draw_resident() -> void:
	var piece := get_parent() as AlkkagiPiece
	if piece == null:
		return
	var radius := piece.visual_radius
	var pulse := 0.5 + 0.5 * sin(_time * 3.2)
	# 합쳐진 돌 둘레: 먹 테두리 위에 금빛 선이 숨 쉬듯 두꺼워졌다 얇아진다.
	draw_arc(Vector2.ZERO, radius + 4.0 + pulse * 1.5, 0.0, TAU, 40, Color(InkStyle.INK, 0.9), 5.0, true)
	draw_arc(Vector2.ZERO, radius + 4.0 + pulse * 1.5, 0.0, TAU, 40, GOLD, 2.4 + pulse, true)
	var count := mini(piece.carried_count, 8)
	for i in count:
		var angle := _time * 0.9 + TAU * float(i) / float(maxi(count, 1))
		_ink_disc(Vector2.RIGHT.rotated(angle) * (radius + 4.0 + pulse * 2.0), 4.5, 1.0)
