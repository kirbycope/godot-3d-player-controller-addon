class_name StateMachine
extends Node

enum States {
	CLIMBING,
	HANGING,
	PARAGLIDING,
	SLIDING,
	STANDING,
}

@export var player: Player


## Finds the state node for the given state and then calls its "start()" function.
func travel(state: States) -> void:
	match state:
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
			push_error("Invalid state: %s" % str(state))
