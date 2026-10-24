class_name AugmentManager
extends Node

signal augment_acquired(player_id: int, definition: AugmentDefinition)

const CATALOG: Array[AugmentDefinition] = [
	preload("res://resources/augments/triple_shot.tres"),
	preload("res://resources/augments/stasis.tres"),
	preload("res://resources/augments/dodge.tres"),
	preload("res://resources/augments/janggi.tres"),
	preload("res://resources/augments/piggyback.tres"),
	preload("res://resources/augments/lantern.tres"),
	preload("res://resources/augments/connect_four.tres"),
	preload("res://resources/augments/snowball.tres"),
	preload("res://resources/augments/wizard.tres"),
	preload("res://resources/augments/tank.tres"),
	preload("res://resources/augments/coup.tres"),
	preload("res://resources/augments/king.tres"),
	preload("res://resources/augments/greatsword.tres"),
	preload("res://resources/augments/sonic_boom.tres"),
	preload("res://resources/augments/train.tres"),
	preload("res://resources/augments/blizzard.tres"),
	preload("res://resources/augments/blind.tres"),
	preload("res://resources/augments/wall_maria.tres"),
	preload("res://resources/augments/scope.tres"),
	preload("res://resources/augments/marksman.tres"),
	preload("res://resources/augments/blood_festival.tres"),
	preload("res://resources/augments/gravity_field.tres"),
	preload("res://resources/augments/stealth.tres"),
	preload("res://resources/augments/earthquake.tres"),
	preload("res://resources/augments/wish.tres"),
]

var owned: Dictionary = {1: [], 2: []}
var effects: Dictionary = {1: [], 2: []}
var completed_turns: Dictionary = {1: 0, 2: 0}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func reset_match() -> void:
	owned = {1: [], 2: []}
	effects = {1: [], 2: []}
	completed_turns = {1: 0, 2: 0}

func get_choices(player_id: int, count: int = 3) -> Array[AugmentDefinition]:
	var pool: Array[AugmentDefinition] = []
	if owned[player_id].size() >= GameplayRules.MAX_AUGMENTS_PER_PLAYER:
		return pool
	for definition in CATALOG:
		if definition.enabled and not has_augment(player_id, definition.id):
			pool.append(definition)
	# Fisher-Yates: 향후 호스트 RNG 결과만 동기화할 수 있는 단일 지점이다.
	for index in range(pool.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = temporary
	return pool.slice(0, mini(count, pool.size()))

func acquire(game: Node, player_id: int, augment_id: StringName) -> bool:
	if player_id not in owned or owned[player_id].size() >= GameplayRules.MAX_AUGMENTS_PER_PLAYER or has_augment(player_id, augment_id):
		return false
	var definition := get_definition(augment_id)
	if definition == null or not definition.enabled or definition.effect_script == null:
		return false
	var effect := definition.effect_script.new() as AugmentEffect
	effect.setup(definition)
	effect.owner_id = player_id
	owned[player_id].append(definition)
	effects[player_id].append(effect)
	effect.on_acquired(game, player_id)
	augment_acquired.emit(player_id, definition)
	return true

func apply_owned_to_piece(player_id: int, piece: AlkkagiPiece) -> void:
	for effect: AugmentEffect in effects[player_id]:
		effect.apply_to_piece(piece)

func shot_profile(player_id: int) -> Dictionary:
	var impulse := 1.0
	var max_drag := 1.0
	var guide := 1.0
	for effect: AugmentEffect in effects[player_id]:
		impulse *= effect.impulse_multiplier()
		max_drag *= effect.max_drag_multiplier()
		guide *= effect.guide_multiplier()
	return {"impulse_multiplier": impulse, "max_drag_multiplier": max_drag, "guide_multiplier": guide, "speed_multiplier": impulse * max_drag}

func before_shot(player_id: int, piece: AlkkagiPiece) -> void:
	for effect: AugmentEffect in effects[player_id]:
		effect.before_shot(piece)

func transform_shot(game: Node, player_id: int, piece: AlkkagiPiece, impulse: Vector2) -> bool:
	for effect: AugmentEffect in effects[player_id]:
		if effect.transform_shot(game, player_id, piece, impulse):
			return true
	return false

func notify_opponent_shot(game: Node, shooter_id: int, piece: AlkkagiPiece, impulse: Vector2) -> void:
	var opponent := 2 if shooter_id == 1 else 1
	for effect: AugmentEffect in effects[opponent]:
		effect.on_opponent_shot(game, opponent, piece, impulse)

func after_shot(game: Node, player_id: int, piece: AlkkagiPiece) -> void:
	for effect: AugmentEffect in effects[player_id]:
		effect.after_shot(game, player_id, piece)

func grants_bonus_turn(game: Node, player_id: int, opponent_eliminated: int) -> bool:
	for effect: AugmentEffect in effects[player_id]:
		if effect.grants_bonus_turn(game, player_id, opponent_eliminated):
			return true
	return false

func adjust_pointer(game: Node, player_id: int, piece: AlkkagiPiece, pointer: Vector2) -> Vector2:
	var result := pointer
	for effect: AugmentEffect in effects[player_id]:
		result = effect.adjust_pointer(game, player_id, piece, result)
	return result

func active_effects(player_id: int) -> Array[AugmentEffect]:
	var result: Array[AugmentEffect] = []
	for effect: AugmentEffect in effects[player_id]:
		if effect.is_active():
			result.append(effect)
	return result

func check_special_victory(game: Node) -> int:
	for player_id in [1, 2]:
		for effect: AugmentEffect in effects[player_id]:
			if effect.check_special_victory(game, player_id):
				return player_id
	return 0

func physics_tick(game: Node, delta: float) -> void:
	for player_id in [1, 2]:
		for effect: AugmentEffect in effects[player_id]:
			effect.on_physics_tick(game, player_id, delta)

func finish_turn(game: Node, player_id: int) -> void:
	completed_turns[player_id] += 1
	for effect: AugmentEffect in effects[player_id]:
		effect.on_turn_ended(game, player_id)

func can_acquire(player_id: int) -> bool:
	return player_id in owned and owned[player_id].size() < GameplayRules.MAX_AUGMENTS_PER_PLAYER

func has_augment(player_id: int, augment_id: StringName) -> bool:
	for definition: AugmentDefinition in owned[player_id]:
		if definition.id == augment_id:
			return true
	return false

func get_definition(augment_id: StringName) -> AugmentDefinition:
	for definition in CATALOG:
		if definition.id == augment_id:
			return definition
	return null
