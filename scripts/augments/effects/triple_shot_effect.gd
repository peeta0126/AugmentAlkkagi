class_name TripleShotAugmentEffect
extends AugmentEffect

var armed := false

func activate_immediate(game: Node, player_id: int) -> void:
	armed = true
	game.board.add_effect_line(game.player_center(player_id) + Vector2(-30, 0), game.player_center(player_id) + Vector2(30, 0), Color("ff8d70"), 0.8, 5.0)
	commit_use(game, player_id)

func transform_shot(game: Node, player_id: int, piece: AlkkagiPiece, impulse: Vector2) -> bool:
	if not armed or piece.fragment_factor < 1.0:
		return false
	armed = false
	game.split_piece_and_launch(piece, player_id, impulse, float(definition.values.get("spread_degrees", 12.0)))
	return true

func status_text() -> String:
	return "다음 발사 준비" if armed else super.status_text()

func network_state() -> Dictionary:
	return {"armed": armed}

func apply_network_state(_game: Node, state: Dictionary) -> void:
	armed = bool(state.get("armed", armed))
