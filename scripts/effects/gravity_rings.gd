class_name GravityRings
extends Node2D
## 중력장 모양: 바깥 점선 고리, 안쪽으로 감기는 소용돌이 팔, 안으로 흘러드는 화살표. 반지름 125 기준으로 그린다.

const RADIUS := 125.0
const INK := Color(0.11, 0.08, 0.07)
const BRASS := Color(0.96, 0.54, 0.12)

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# 바닥에 깔린 어두운 원판(가운데가 진하다)
	for i in 9:
		var t := float(i) / 8.0
		draw_circle(Vector2.ZERO, RADIUS * (1.0 - t * 0.9), Color(INK.r * 0.5, INK.g * 0.45, INK.b * 0.8, 0.045))
	# 바깥 고리: 천천히 도는 점선
	var segments := 36
	for i in segments:
		var a0 := TAU * i / segments + _time * 0.35
		draw_arc(Vector2.ZERO, RADIUS, a0, a0 + TAU / segments * 0.58, 6, Color(INK.r, INK.g, INK.b, 0.9), 3.0, true)
	draw_arc(Vector2.ZERO, RADIUS * 0.66, 0.0, TAU, 72, Color(INK.r, INK.g, INK.b, 0.35), 1.6, true)
	draw_arc(Vector2.ZERO, RADIUS * 0.34, 0.0, TAU, 56, Color(BRASS.r, BRASS.g, BRASS.b, 0.55), 1.6, true)
	# 소용돌이 팔 3개: 안쪽으로 감기며 점점 옅어진다.
	for arm in 3:
		var base := TAU * arm / 3.0 - _time * 0.9
		var prev := Vector2.ZERO
		for k in 29:
			var t := float(k) / 28.0
			var r := RADIUS * (0.97 - 0.82 * t)
			var ang := base + t * 2.3
			var p := Vector2(cos(ang), sin(ang)) * r
			if k > 0:
				draw_line(prev, p, Color(INK.r, INK.g, INK.b, 0.78 * (1.0 - t * 0.75)), 2.6 - 1.2 * t, true)
			prev = p
	# 안으로 흘러드는 화살표
	for i in 6:
		var ang := TAU * i / 6.0 + 0.3
		var f := fmod(_time * 0.55 + float(i) / 6.0, 1.0)
		var r := RADIUS * (0.92 - 0.72 * f)
		var dir := Vector2(cos(ang), sin(ang))
		var tip := dir * r
		var tail := dir * (r + 12.0)
		var side := Vector2(-dir.y, dir.x) * 5.5
		var c := Color(BRASS.r, BRASS.g, BRASS.b, sin(f * PI) * 0.9)
		draw_line(tail + side, tip, c, 2.2, true)
		draw_line(tail - side, tip, c, 2.2, true)
	# 중심: 빨려 들어가는 점
	draw_circle(Vector2.ZERO, 7.0, Color(0.1, 0.07, 0.16, 0.9))
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 28, Color(BRASS.r, BRASS.g, BRASS.b, 0.9), 2.0, true)
