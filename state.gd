class_name NodeStateMachine
extends Node

enum States {
	ATTACKING,
	CLIMBING,
	CROUCHING,
	DRIVING,
	FALLING,
	HANGING,
	JUMPING,
	PARAGLIDING,
	SKATEBOARDING,
	SLIDING,
	SPRINTING,
	STANDING,
	SWIMMING,
}

@export var player: Player


## Helper function to get the state name from the `NodeStateMachine.States` enum value.
static func get_state_name(state: int) -> StringName:
	var state_name: Variant = States.find_key(state)
	if state_name == null:
		return &""
	return StringName(String(state_name).capitalize())


## Transition from one state to another.
func travel(from_state: States, to_state: States) -> void:
	if from_state in States.values():
		_stop_state(from_state)
	else:
		push_warning("Invalid from_state: %s" % str(from_state))

	if to_state in States.values():
		_start_state(to_state)
	else:
		push_warning("Invalid to_state: %s" % str(to_state))


## (Do not call this directly) Called by `travel()` to STOP the current state.
func _stop_state(state: int) -> void:
	var state_name: StringName = get_state_name(state)
	var state_node: Node = get_node_or_null(NodePath(state_name))
	if state_node == null:
		push_error("Invalid from_state: %s" % str(state_name))
		return
	if not state_node.has_method("stop"):
		push_error("State %s missing stop()" % str(state_name))
		return
	state_node.call("stop")


## (Do not call this directly) Called by `travel()` to START the new state.
func _start_state(state: States) -> void:
	var state_name: StringName = get_state_name(state)
	var state_node: Node = get_node_or_null(NodePath(state_name))
	if state_node == null:
		push_error("Invalid to_state: %s" % str(state_name))
		return
	if not state_node.has_method("start"):
		push_error("State %s missing start()" % str(state_name))
		return
	state_node.call("start")
