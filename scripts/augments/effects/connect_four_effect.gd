class_name ConnectFourAugmentEffect
extends AugmentEffect

var winning_line := PackedVector2Array()

func check_special_victory(game: Node, player_id: int) -> bool:
	winning_line = game.find_connect_four(
		player_id,
		float(definition.values.get("gap_multiplier", 2.0)),
		float(definition.values.get("alignment_tolerance", 14.0)),
		float(definition.values.get("minimum_gap_multiplier", 0.65))
	)
	_update_visual(game, player_id)
	return winning_line.size() == 2

func network_state() -> Dictionary:
	return {"line": winning_line}

func apply_network_state(game: Node, state: Dictionary) -> void:
	winning_line = state.get("line", PackedVector2Array())
	_update_visual(game, owner_id)

func _update_visual(game: Node, player_id: int) -> void:
	if game.board == null:
		return
	var key := "connect_four_%d" % player_id
	if winning_line.size() == 2:
		game.board.set_field_visual(key, {
			"type": "connect_four",
			"from": winning_line[0],
			"to": winning_line[1],
			"color": AlkkagiPiece.OWNER_COLORS[player_id]
		})
	else:
		game.board.remove_field_visual(key)
