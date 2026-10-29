extends "res://scripts/network/network_manager.gd"
var reply: Dictionary = {}
func _ready() -> void:
	pass
func _remote_sender_id() -> int:
	return 22
func _send_active_result(_peer: int, sequence: int, result: Dictionary) -> void:
	reply = result.duplicate(true)
	reply["sequence"] = sequence

