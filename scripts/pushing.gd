class_name Pushing
extends NodeStateMachine

## Grace period for momentary loss of wall contact (root motion can pulse the collision).
const STOP_GRACE_TIME: float = 0.4

var _this_state: NodeStateMachine.States = NodeStateMachine.States.PUSHING
var _stop_grace_remaining: float = 0.0


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:

	# Do nothing if the player is not set
	if not player: return

	# Check if the player is no longer on the floor
	if not player.is_on_floor() and not player.falling_raycast.is_colliding():
		# Start "falling"
		player.state_machine.travel(_this_state, NodeStateMachine.States.FALLING)
		return

	# Check if the player has stopped moving
	if not player.has_move_input:
		# Start "standing"
		player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
		return

	# Check if the player has lost wall contact (with a grace period for root motion pulses)
	if player.is_on_wall():
		_stop_grace_remaining = STOP_GRACE_TIME
	else:
		_stop_grace_remaining -= delta
		if _stop_grace_remaining <= 0.0:
			# Start "standing"
			player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
			return


## Start "pushing".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
	# Reset the wall contact grace period
	_stop_grace_remaining = STOP_GRACE_TIME
	# Flag the player as "pushing"; the AnimationTree auto-advances StandingLocomotion -> PushingStart -> Pushing
	player.is_pushing = true


## Stop "pushing".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "pushing"; the AnimationTree auto-advances Pushing -> PushingStop -> StandingLocomotion
	player.is_pushing = false
