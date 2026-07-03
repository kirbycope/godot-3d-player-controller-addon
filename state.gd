class_name NodeStateMachine
extends Node

enum States {
	CLIMBING,
	FALLING,
	HANGING,
	PARAGLIDING,
	SLIDING,
}

@export var player: Player


func travel(to_state: States, from_state: int = -1) -> void:
	# If state is not specified, use the player's current state as the from_state.
	var current_state: int = player.current_state if from_state == -1 else from_state

	if current_state != -1:
		_stop_state(current_state)
	_start_state(to_state)


func _stop_state(state: int) -> void:
	var state_name: StringName = _get_state_name(state)
	var state_node: Node = get_node_or_null(NodePath(state_name))
	if state_node == null:
		push_error("Invalid from_state: %s" % str(state))
		return
	if not state_node.has_method("stop"):
		push_error("State %s missing stop()" % str(state))
		return
	state_node.call("stop")


func _start_state(state: States) -> void:
	var state_name: StringName = _get_state_name(state)
	var state_node: Node = get_node_or_null(NodePath(state_name))
	if state_node == null:
		push_error("Invalid to_state: %s" % str(state))
		return
	if not state_node.has_method("start"):
		push_error("State %s missing start()" % str(state))
		return
	state_node.call("start")


func _get_state_name(state: int) -> StringName:
	var state_name: Variant = States.find_key(state)
	if state_name == null:
		return &""
	return StringName(String(state_name).capitalize())
