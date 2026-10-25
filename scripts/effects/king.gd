class_name KingVisual
extends Node2D

@onready var aura: Node2D = %GoldenAura

func _ready() -> void:
	scale = Vector2(0.4, 0.4)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(self, "scale", Vector2.ONE, 0.45)

func set_shockwave_available(available: bool) -> void:
	aura.modulate.a = 0.9 if available else 0.35

func _process(delta: float) -> void:
	aura.rotation += delta * 0.45
