class_name CoinTossVisual
extends Control
## 시작 선공을 정하는 동전 던지기 연출. 결과는 이미 정해져 있고, 이 화면은 보여 주기만 한다.

signal finished

const FACES := {
	1: preload("res://assets/coin/coin_black.png"),
	2: preload("res://assets/coin/coin_white.png"),
}
const FLIPS := 7
const FLIP_SECONDS := 1.9
const COIN_SIZE := 150.0
const RESULT_HOLD_SECONDS := 3.0

var coin: TextureRect
var caption: Label
var result_getter: Callable

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.015, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	caption = Label.new()
	caption.text = "동전 던지기"
	caption.add_theme_font_size_override("font_size", 34)
	caption.add_theme_color_override("font_color", Color("f4d79a"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(340, 150)
	caption.size = Vector2(600, 56)
	caption.modulate.a = 0.0
	add_child(caption)
	coin = TextureRect.new()
	coin.texture = FACES[1]
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_SCALE
	coin.size = Vector2(COIN_SIZE, COIN_SIZE)
	coin.pivot_offset = coin.size * 0.5
	coin.position = Vector2(640.0 - COIN_SIZE * 0.5, 470.0)
	coin.modulate.a = 0.0
	add_child(coin)
	var fade := create_tween().set_parallel(true)
	fade.tween_property(dim, "color:a", 0.62, 0.3)
	fade.tween_property(caption, "modulate:a", 1.0, 0.3)
	fade.tween_property(coin, "modulate:a", 1.0, 0.3)

## 결과(1 흑, 2 백)를 돌려주는 함수를 받아 동전을 던진다. 참가자는 호스트 결과가 도착할 시간을 벌기 위해 끝에서 읽는다.
func play(get_result: Callable) -> void:
	result_getter = get_result
	await get_tree().create_timer(0.35).timeout
	var start_y := coin.position.y
	var peak_y := 190.0
	var toss := create_tween()
	toss.tween_method(_animate.bind(start_y, peak_y), 0.0, 1.0, FLIP_SECONDS)
	await toss.finished
	var winner := int(result_getter.call())
	coin.scale = Vector2.ONE
	coin.position.y = start_y
	coin.texture = FACES.get(winner, FACES[1])
	caption.text = "%s 선공!" % AlkkagiPiece.STONE_NAMES[winner]
	var pop := create_tween()
	pop.tween_property(coin, "scale", Vector2(1.25, 1.25), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(coin, "scale", Vector2.ONE, 0.12)
	await get_tree().create_timer(RESULT_HOLD_SECONDS).timeout
	var out := create_tween().set_parallel(true)
	out.tween_property(self, "modulate:a", 0.0, 0.35)
	await out.finished
	finished.emit()
	queue_free()

# t: 0~1. 포물선으로 올라갔다 내려오며 세로축으로 FLIPS번 뒤집힌다(납작해졌을 때 앞뒷면 교체).
func _animate(t: float, start_y: float, peak_y: float) -> void:
	var arc := 4.0 * t * (1.0 - t)
	coin.position.y = lerpf(start_y, peak_y, arc)
	var phase := t * FLIPS * PI
	var flip := absf(cos(phase))
	var grow := 1.0 + 0.18 * arc
	coin.scale = Vector2(grow, maxf(flip, 0.08) * grow)
	var showing_black := int(floor(phase / PI)) % 2 == 0
	coin.texture = FACES[1] if showing_black else FACES[2]
