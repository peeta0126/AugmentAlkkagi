class_name GameStateMachine
extends Node

signal state_changed(previous: State, current: State)

enum State {
	MAIN_MENU,
	LOCAL_SETUP,
	CREATE_ROOM,
	JOIN_ROOM,
	LOBBY,
	INITIAL_AUGMENT_SELECTION,
	PLAYER_AIMING,
	PIECES_MOVING,
	TURN_RESOLUTION,
	AUGMENT_SELECTION,
	SKILL_TARGETING,
	GAME_OVER,
	PAUSED,
}

var current: State = State.MAIN_MENU

func transition(next: State) -> void:
	if next == current:
		return
	var previous := current
	current = next
	state_changed.emit(previous, current)

func allows_aiming() -> bool:
	return current == State.PLAYER_AIMING
