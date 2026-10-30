class_name JanggiVisual
extends Node2D
## 장기말 표시: 돌 위에 팔각 장기 패를 얹고 한자를 크게 쓴다. 장기처럼 초(楚)는 초록, 한(漢)은 붉은 먹으로 쓴다.
## 바뀌는 순간 패가 내려앉으며 먹으로 친 붓 고리가 그어지고 먹물이 튄다. 돌 가장자리가 보이도록 패는 돌보다 작다.

const SYMBOLS_CHO := {
	"SOLDIER": "卒", "CHARIOT": "車", "CANNON": "包", "HORSE": "馬",
	"ELEPHANT": "象", "GUARD": "士", "KING": "楚"
}
const SYMBOLS_HAN := {
	"SOLDIER": "兵", "CHARIOT": "車", "CANNON": "包", "HORSE": "馬",
	"ELEPHANT": "象", "GUARD": "士", "KING": "漢"
}
const SHEET: Texture2D = preload("res://assets/effects/janggi_sheet.png")
const PAPER := Color("f3e3c0")
const PAPER_SHADE := Color("d9c493")
const INK := Color("1c1512")
const CHO_GREEN := Color("2f8a55")
const HAN_RED := Color("c93a2b")

var kind := ""
var _pop := 1.0  # 0 → 1: 등장 연출 진행도
var _tween: Tween


func configure(new_kind: String) -> void:
	if new_kind != kind:
		var first := kind == ""
		kind = new_kind
		if first:
			_pop = 0.0
			if _tween != null:
				_tween.kill()
			_tween = create_tween()
			_tween.tween_property(self, "_pop", 1.0, 0.5)
			_play_ink()
	queue_redraw()


func _owner_id() -> int:
	var piece := get_parent() as AlkkagiPiece
	return piece.owner_id if piece != null else 1


func _team_color() -> Color:
	return CHO_GREEN if _owner_id() == 1 else HAN_RED


func _play_ink() -> void:
	# 바뀌는 순간 먹으로 친 붓 고리가 그어진다(초는 초록 먹, 한은 붉은 먹).
	var radius := 13.3
	var piece := get_parent() as AlkkagiPiece
	if piece != null:
		radius = piece.visual_radius
	var row := 0 if _owner_id() == 1 else 1
	var sprite := Sprite2D.new()
	sprite.texture = SHEET
	sprite.hframes = 4
	sprite.vframes = 2
	sprite.frame = row * 4
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2.ONE * (radius * 2.5 / 80.0)
	sprite.z_index = 5
	add_child(sprite)
	var tween := create_tween()
	for i in 4:
		tween.tween_callback(func(): sprite.frame = row * 4 + i)
		tween.tween_interval(0.12)
	tween.tween_callback(sprite.queue_free)


func _process(_delta: float) -> void:
	if _pop < 1.0:
		queue_redraw()


func _octagon(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 8:
		points.append(Vector2.RIGHT.rotated(TAU * (float(i) + 0.5) / 8.0) * radius)
	return points


func _draw() -> void:
	if kind == "":
		return
	var piece := get_parent() as AlkkagiPiece
	var radius := piece.visual_radius if piece != null else 13.3
	var team := _team_color()
	var land := clampf(_pop / 0.35, 0.0, 1.0)
	var token_scale := lerpf(1.9, 1.0, land * land * (3.0 - 2.0 * land)) if _pop < 0.35 else 1.0
	var token_alpha := clampf(_pop / 0.12, 0.0, 1.0)
	var r := radius * 0.78 * token_scale
	# 그림자 → 먹 테두리 → 종이 → 안쪽 팀색 선 순서로 쌓는다.
	draw_colored_polygon(_octagon(r + 4.0 + (3.0 if token_scale > 1.0 else 0.0)), Color(INK, 0.35 * token_alpha))
	draw_colored_polygon(_octagon(r + 2.5), Color(INK, token_alpha))
	draw_colored_polygon(_octagon(r), Color(PAPER, token_alpha))
	var inner := _octagon(r * 0.82)
	inner.append(inner[0])
	draw_polyline(inner, Color(team, token_alpha), maxf(r * 0.1, 1.6), true)
	var symbols := SYMBOLS_CHO if _owner_id() == 1 else SYMBOLS_HAN
	var glyph := str(symbols.get(kind, kind.left(1)))
	var font := ThemeDB.fallback_font
	var size := int(r * 1.35)
	var glyph_pos := Vector2(-r, size * 0.34)
	draw_string(font, glyph_pos + Vector2(0.8, 1.0), glyph, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, size, Color(PAPER_SHADE, token_alpha * 0.9))
	draw_string(font, glyph_pos, glyph, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, size, Color(team.darkened(0.2), token_alpha))
