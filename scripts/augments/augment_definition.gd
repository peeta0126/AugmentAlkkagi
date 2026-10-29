class_name AugmentDefinition
extends Resource

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
enum Kind { PASSIVE, SHOT, FIELD, ACTIVE, CONDITIONAL }
enum TargetMode { NONE, OWN_PIECE, ENEMY_PIECE, TWO_OWN_PIECES, BOARD_POSITION }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var rarity: Rarity = Rarity.COMMON
@export var icon_text := "◆"
@export var kind: Kind = Kind.PASSIVE
@export var trigger_description := "획득 즉시"
@export var target_mode: TargetMode = TargetMode.NONE
@export var max_uses := -1
@export var cooldown_turns := 0
@export var duration_turns := 0
@export var consumes_turn := true
@export var values: Dictionary = {}
@export var stackable := false
@export_range(1, 20) var max_stacks := 1
@export var enabled := true
@export var effect_script: Script

func rarity_name() -> String:
	return ["일반", "희귀", "영웅", "전설"][rarity]

func kind_name() -> String:
	return ["패시브", "발사", "필드", "액티브", "조건부"][kind]

func rarity_color() -> Color:
	return [Color("c9c0ae"), Color("7ea3c4"), Color("a68bc0"), Color("dcae52")][rarity]
