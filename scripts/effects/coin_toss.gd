class_name CoinTossVisual
extends Control
## 시작 선공을 정하는 동전 던지기 연출. 결과는 이미 정해져 있고, 이 화면은 보여 주기만 한다.
## 붓 터치 제목 아래에서 동전이 뒤집히다 떨어지면, 주황 폭발과 함께 선공이 크게 나온다.

signal finished

const FACES := {
	1: preload("res://assets/coin/coin_black.png"),
	2: preload("res://assets/coin/coin_white.png"),
}
const FLIPS := 7
const FLIP_SECONDS := 1.9
const COIN_SIZE := 190.0
const RESULT_HOLD_SECONDS := 3.0
const GROUND_Y := 372.0
const PEAK_Y := 214.0

var coin: TextureRect
var caption: Label
var result_getter: Callable

var _sub: Label
var _swash: TextureRect
var _burst: TextureRect
var _shadow: Panel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.025, 0.015, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var vignette := TextureRect.new()
	vignette.texture = InkStyle.VIGNETTE_TEXTURE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	_burst = TextureRect.new()
	_burst.texture = InkStyle.BURST_TEXTURE
	_burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_burst.stretch_mode = TextureRect.STRETCH_SCALE
	_burst.size = Vector2(470.0, 470.0)
	_burst.position = Vector2(640.0 - 235.0, GROUND_Y - 235.0 + COIN_SIZE * 0.5)
	_burst.pivot_offset = _burst.size * 0.5
	_burst.modulate.a = 0.0
	_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_burst)

	_swash = TextureRect.new()
	_swash.texture = InkStyle.SWASH_TEXTURE
	_swash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_swash.stretch_mode = TextureRect.STRETCH_SCALE
	_swash.size = Vector2(820.0, 150.0)
	_swash.position = Vector2(640.0 - 410.0, 44.0)
	_swash.pivot_offset = _swash.size * 0.5
	_swash.modulate.a = 0.0
	_swash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_swash)

	caption = Label.new()
	caption.text = "선공 정하기"
	caption.size = Vector2(760.0, 90.0)
	caption.position = Vector2(640.0 - 380.0, 74.0)
	caption.pivot_offset = caption.size * 0.5
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.modulate.a = 0.0
	InkStyle.brush_label(caption, 54, InkStyle.CREAM, 16)
	add_child(caption)

	_sub = Label.new()
	_sub.text = "동전을 던집니다"
	_sub.size = Vector2(760.0, 40.0)
	_sub.position = Vector2(640.0 - 380.0, 196.0)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.modulate.a = 0.0
	InkStyle.outline_label(_sub, 24, InkStyle.CREAM_SOFT, 8)
	add_child(_sub)

	_shadow = Panel.new()
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.4)
	shadow_style.set_corner_radius_all(100)
	_shadow.add_theme_stylebox_override("panel", shadow_style)
	_shadow.size = Vector2(150.0, 30.0)
	_shadow.position = Vector2(640.0 - 75.0, GROUND_Y + COIN_SIZE - 14.0)
	_shadow.pivot_offset = _shadow.size * 0.5
	_shadow.modulate.a = 0.0
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shadow)

	coin = TextureRect.new()
	coin.texture = FACES[1]
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_SCALE
	coin.size = Vector2(COIN_SIZE, COIN_SIZE)
	coin.pivot_offset = coin.size * 0.5
	coin.position = Vector2(640.0 - COIN_SIZE * 0.5, GROUND_Y)
	coin.modulate.a = 0.0
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coin)

	var fade := create_tween().set_parallel(true)
	fade.tween_property(dim, "color:a", 0.66, 0.3)
	fade.tween_property(_swash, "modulate:a", 1.0, 0.25)
	fade.tween_property(caption, "modulate:a", 1.0, 0.25)
	fade.tween_property(_sub, "modulate:a", 1.0, 0.3)
	fade.tween_property(coin, "modulate:a", 1.0, 0.3)
	fade.tween_property(_shadow, "modulate:a", 1.0, 0.3)


## 결과(1 흑, 2 백)를 돌려주는 함수를 받아 동전을 던진다. 참가자는 호스트 결과가 도착할 시간을 벌기 위해 끝에서 읽는다.
func play(get_result: Callable) -> void:
	result_getter = get_result
	await get_tree().create_timer(0.35).timeout
	var toss := create_tween()
	toss.tween_method(_animate, 0.0, 1.0, FLIP_SECONDS)
	await toss.finished
	var winner := int(result_getter.call())
	coin.scale = Vector2.ONE
	coin.position.y = GROUND_Y
	coin.texture = FACES.get(winner, FACES[1])
	_shadow.scale = Vector2.ONE
	caption.text = "%s 선공!" % AlkkagiPiece.STONE_NAMES[winner]
	_sub.text = "먼저 돌을 쏩니다"

	# 착지: 폭발이 터지고, 동전과 제목이 통통 튄다.
	_burst.scale = Vector2(0.25, 0.25)
	_burst.rotation = randf_range(-0.1, 0.1)
	_burst.modulate.a = 1.0
	var pop := create_tween().set_parallel(true)
	pop.tween_property(_burst, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(coin, "scale", Vector2(1.3, 1.3), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.chain().tween_property(coin, "scale", Vector2.ONE, 0.14)
	var title_pop := create_tween().set_parallel(true)
	caption.scale = Vector2(0.6, 0.6)
	_swash.scale = Vector2(0.8, 0.8)
	title_pop.tween_property(caption, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	title_pop.tween_property(_swash, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(RESULT_HOLD_SECONDS).timeout
	var out := create_tween().set_parallel(true)
	out.tween_property(self, "modulate:a", 0.0, 0.35)
	await out.finished
	finished.emit()
	queue_free()


# t: 0~1. 포물선으로 올라갔다 내려오며 세로축으로 FLIPS번 뒤집힌다(납작해졌을 때 앞뒷면 교체).
func _animate(t: float) -> void:
	var arc := 4.0 * t * (1.0 - t)
	coin.position.y = lerpf(GROUND_Y, PEAK_Y, arc)
	var phase := t * FLIPS * PI
	var flip := absf(cos(phase))
	var grow := 1.0 + 0.18 * arc
	coin.scale = Vector2(grow, maxf(flip, 0.08) * grow)
	coin.texture = FACES[1] if int(floor(phase / PI)) % 2 == 0 else FACES[2]
	_shadow.scale = Vector2.ONE * (1.0 - 0.55 * arc)
	_shadow.modulate.a = 1.0 - 0.6 * arc
