class_name PiggybackAugmentEffect
extends AugmentEffect

var carrier: AlkkagiPiece

func on_piece_target(game: Node, player_id: int, piece: AlkkagiPiece) -> bool:
	if piece.owner_id != player_id:
		return false
	if carrier == null:
		carrier = piece
		game.set_skill_hint("업을 알을 선택했습니다. 업힐 다른 아군 알을 선택하세요.")
		return false
	if piece == carrier:
		return false
	carrier.carried_count += 1
	carrier.refresh_physics()
	game.board.add_effect_line(piece.position, carrier.position, Color("e5b56d"), 0.7, 4.0)
	piece.queue_free()
	carrier = null
	commit_use(game, player_id)
	return true

func cancel_active() -> void:
	carrier = null
