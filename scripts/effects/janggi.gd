class_name JanggiVisual
extends Node2D
## 장기말 표시: 돌 위에 한자를 검정 외곽선으로 크게 써 넣는다. 한(漢)쪽 말은 주황, 장(將)은 붉은색.

const SYMBOLS := {
	"SOLDIER": "卒", "CHARIOT": "車", "CANNON": "包", "HORSE": "馬",
	"ELEPHANT": "象", "GUARD": "士", "KING": "將"
}

@onready var piece_symbol: Label = %PieceSymbol


func configure(kind: String) -> void:
	piece_symbol.text = str(SYMBOLS.get(kind, kind.left(1)))
	piece_symbol.add_theme_font_size_override("font_size", 19)
	piece_symbol.add_theme_color_override("font_color", Color("ffb347") if kind != "KING" else Color("ff6a4d"))
	piece_symbol.add_theme_color_override("font_outline_color", Color("1c1512"))
	piece_symbol.add_theme_constant_override("outline_size", 7)
