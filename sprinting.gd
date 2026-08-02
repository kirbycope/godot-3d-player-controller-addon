class_name Sprinting
extends NodeStateMachine

var _this_state := NodeStateMachine.States.SPRINTING


## Called when there is an input event.
func _input(event: InputEvent) -> void:

	# Do nothing if the player is not set
	if not player or player.is_paused or player.is_ragdolling: return

	# Attack
	if event.is_action_pressed("attack") and player.inventory.can_player_attack:
		player.state_machine.travel(_this_state, NodeStateMachine.States.ATTACKING)
		return

	# Jump
	if event.is_action_pressed("jump"):
		if player.is_boxing:
			player.is_boxing = false
		player.state_machine.travel(_this_state, NodeStateMachine.States.JUMPING)
		return

	# Slide
	if event.is_action_pressed("crouch"):
		player.state_machine.travel(_this_state, NodeStateMachine.States.SLIDING)
		return

	# Sprint { Microsoft: Ⓑ, Nintendo: Ⓐ, Sony: Ⓞ, Keyboard: [Shift] }.
	if event.is_action_released("sprint"):
		# Start "standing"
		player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
		return


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Do nothing if the player is not set
	if not player: return

	# Check if the player is no longer on the floor
	if not player.is_on_floor() and not player.falling_raycast.is_colliding():
		# Start "falling"
		player.state_machine.travel(_this_state, NodeStateMachine.States.FALLING)
		return


## Start "sprinting".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
	# Flag the player as "sprinting"
	player.is_sprinting = true


## Stop "sprinting".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "sprinting"
	player.is_sprinting = false
