class_name JanggiVisual
extends Node2D

const SYMBOLS := {
	"SOLDIER": "卒", "CHARIOT": "車", "CANNON": "包", "HORSE": "馬",
	"ELEPHANT": "象", "GUARD": "士", "KING": "將"
}

@onready var piece_symbol: Label = %PieceSymbol


func configure(kind: String) -> void:
	piece_symbol.text = str(SYMBOLS.get(kind, kind.left(1)))
	piece_symbol.modulate = Color("ffda78") if kind != "KING" else Color("ff765c")
