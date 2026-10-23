class_name WizardAugmentEffect
extends AugmentEffect

var wizard: AlkkagiPiece

func on_piece_target(game: Node, player_id: int, piece: AlkkagiPiece) -> bool:
	if wizard == null:
		if piece.owner_id != player_id:
			return false
		wizard = piece
		wizard.transform_as("WIZARD")
		game.set_skill_hint("화염구로 공격할 상대 알을 선택하세요.")
		return false
	if piece.owner_id == player_id:
		return false
	var direction := (piece.position - wizard.position).normalized()
	piece.sleeping = false
	piece.apply_central_impulse(direction * float(definition.values.get("knockback", 420.0)))
	game.animate_projectile(wizard.position, piece.position, Color("ff642e"), 8.0)
	game.board.add_effect_line(wizard.position, piece.position, Color("ff642e"), 0.55, 7.0)
	wizard = null
	commit_use(game, player_id)
	return true

func cancel_active() -> void:
	wizard = null
