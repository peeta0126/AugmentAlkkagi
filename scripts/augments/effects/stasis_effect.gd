class_name StasisAugmentEffect
extends AugmentEffect

var target_ids: Array[int] = []

func activate_immediate(game: Node, player_id: int) -> void:
	for piece: AlkkagiPiece in game.get_pieces():
		if piece.owner_id != player_id:
			continue
		piece.set_stasis(int(definition.duration_turns))
		piece.stasis_cycle_based = true
		target_ids.append(piece.piece_id)
	commit_use(game, player_id)

func on_owner_cycle(game: Node) -> void:
	for id in target_ids:
		var piece: AlkkagiPiece = game.find_piece(id)
		if piece != null:
			piece.tick_stasis_cycle()

func network_state() -> Dictionary:
	return {"target_ids": target_ids}

func apply_network_state(_game: Node, state: Dictionary) -> void:
	target_ids.assign(state.get("target_ids", []))
