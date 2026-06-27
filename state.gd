class_name NodeStateMachine
extends Node

enum States {
	CLIMBING,
	HANGING,
	PARAGLIDING,
	SLIDING,
	STANDING,
}

@export var player: Player


func travel(to_state: States, from_state: int = -1) -> void:
	# If state is not specified, use the player's current state as the from_state
	var f_state: int = player.current_state if from_state == -1 else from_state

	# Stop the current state before transitioning to the new state
	match f_state:
		States.CLIMBING:
			get_node("Climbing").stop()
		States.HANGING:
			get_node("Hanging").stop()
		States.PARAGLIDING:
			get_node("Paragliding").stop()
		States.SLIDING:
			get_node("Sliding").stop()
		States.STANDING:
			get_node("Standing").stop()
		_:
			push_error("Invalid from_state: %s" % str(f_state))

	# Start the new state after stopping the previous one
	match to_state:
		States.CLIMBING:
			get_node("Climbing").start()
		States.HANGING:
			get_node("Hanging").start()
		States.PARAGLIDING:
			get_node("Paragliding").start()
		States.SLIDING:
			get_node("Sliding").start()
		States.STANDING:
			get_node("Standing").start()
		_:
			push_error("Invalid to_state: %s" % str(to_state))
