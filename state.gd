class_name NodeStateMachine
extends Node

enum States {
	ATTACKING,
	CLIMBING,
	CROUCHING,
	FALLING,
	HANGING,
	JUMPING,
	PARAGLIDING,
	SLIDING,
	SPRINTING,
}

@export var player: Player


func travel(to_state: States, from_state: int = -1) -> void:
	# If state is not specified, use the player's current state as the from_state.
	var current_state: int = player.current_state if from_state == -1 else from_state

	if current_state != -1:
		stop_state(current_state)
	start_state(to_state)


func stop_state(state: int) -> void:
	var state_name: StringName = get_state_name(state)
	var state_node: Node = get_node_or_null(NodePath(state_name))
	if state_node == null:
		push_error("Invalid from_state: %s" % str(state))
		return
	if not state_node.has_method("stop"):
		push_error("State %s missing stop()" % str(state))
		return
	state_node.call("stop")


func start_state(state: States) -> void:
	var state_name: StringName = get_state_name(state)
	var state_node: Node = get_node_or_null(NodePath(state_name))
	if state_node == null:
		push_error("Invalid to_state: %s" % str(state))
		return
	if not state_node.has_method("start"):
		push_error("State %s missing start()" % str(state))
		return
	state_node.call("start")


static func get_state_name(state: int) -> StringName:
	var state_name: Variant = States.find_key(state)
	if state_name == null:
		return &""
	return StringName(String(state_name).capitalize())
