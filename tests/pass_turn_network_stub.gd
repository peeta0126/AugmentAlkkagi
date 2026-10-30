extends "res://scripts/network/network_manager.gd"

var sender := 22
var reply: Dictionary = {}

func _ready() -> void:
	pass

func _remote_sender_id() -> int:
	return sender

func _send_pass_result(_peer: int, sequence: int, accepted: bool, snapshot: Dictionary) -> void:
	reply = {"sequence": sequence, "accepted": accepted, "snapshot": snapshot}
