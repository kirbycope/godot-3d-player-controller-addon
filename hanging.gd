class_name Hanging
extends NodeStateMachine

@export_category("Hanging Controls")
@export_group("Keyboard/Mouse Actions")
@export var keyboard_drop_action: StringName = &"crouch"
@export var keyboard_climb_up_action: StringName = &"jump"

@export_group("Controller/Touch Actions")
@export var pad_drop_action: StringName = &"crouch"
@export var pad_climb_up_action: StringName = &"jump"

var _this_state := NodeStateMachine.States.HANGING


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set or is paused/ragdolling
	if not player or player.is_paused or player.is_ragdolling: return

	var input_type = player.controls.current_input_type if player.controls else 0
	var current_drop_action = keyboard_drop_action if input_type == 0 else pad_drop_action
	var current_climb_up_action = keyboard_climb_up_action if input_type == 0 else pad_climb_up_action

	# Drop / Let go
	if event.is_action_pressed(current_drop_action):
		# Stop "hanging" and start "falling"
		player.state_machine.travel(_this_state, NodeStateMachine.States.FALLING)
		return

	# Hanging, Climbing-On [Input]
	if event.is_action_pressed(current_climb_up_action) and not event.is_echo():
		if player.is_hanging_braced:
			player.locomotion_state.travel("BracedHangClimbingOn")
			player.is_climbing_on = true
		elif player.is_hanging_free:
			player.locomotion_state.travel("FreeHangingClimbingOn")
			player.is_climbing_on = true


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Check if the player has reached the floor
	if player.is_on_floor():
		# Start "standing"
		player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
		return

	# Update footing status if not climbing onto a ledge
	if not player.is_climbing_on:
		# Check if "hanging" (braced) [Raycast]
		if player.is_hanging_free \
		and player.hanging_braced_detection.is_colliding():
			player.locomotion_state.travel("BracedHangLocomotion")
			player.is_hanging_braced = true
			player.is_hanging_free = false

		# Check if "hanging" (free) [Raycast]
		if player.is_hanging_braced \
		and not player.hanging_braced_detection.is_colliding():
			player.locomotion_state.travel("FreeHangingLocomotion")
			player.is_hanging_braced = false
			player.is_hanging_free = true

	# Hanging, Climbing On [Status]
	if player.is_climbing_on:
		var was_climbing_on = player.is_climbing_on
		player.is_climbing_on = player.animation_tree.get(player.LOCOMOTION_STATE_PLAYBACK_PATH).get_current_node() in ["BracedHangClimbingOn", "FreeHangingClimbingOn"]
		if was_climbing_on and not player.is_climbing_on:
			player.global_position = player.climbing_on_target
			# Start "standing"
			player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
			return



## Start "hanging".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
	# Determine if the player can hang braced
	if player.hanging_braced_detection.is_colliding():
		# Travel to the "hanging" (braced) locomotion state
		player.locomotion_state.travel("BracedHangLocomotion")
		# Flag the player as "hanging" (braced)
		player.is_hanging_braced = true
	else:
		# Travel to the "hanging" (free) locomotion state
		player.locomotion_state.travel("FreeHangingLocomotion")
		# Flag the player as "hanging" (free)
		player.is_hanging_free = true


## Stop "hanging".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "hanging"
	player.is_hanging_braced = false
	player.is_hanging_free = false
	# Clear ledge detection visuals
	player.ledge_detection_vertical.position = Vector3(0, 0, -1) # Reset to default
	player.ledge_detection_horizontal.hide()
	player.ledge_detection_marker.hide()


func get_contextual_controls(input_type: int) -> Dictionary:
	if not player or not player.controls: return {}

	if input_type == 0: # KEYBOARD_MOUSE
		return {
			player.controls.joypad_button_4_label: "Perspective",
			player.controls.joypad_button_15_label: "Screenshot",
			player.controls.joypad_button_6_label: "Pause Menu",

			player.controls.joypad_button_3_label: "Climb Up",
			player.controls.joypad_button_7_label: "Drop",
			player.controls.left_joystick_label: "Shimmy",
			player.controls.right_joystick_label: "Camera",
		}
	else:
		return {
			player.controls.joypad_button_4_label: "Perspective",
			player.controls.joypad_button_15_label: "Screenshot",
			player.controls.joypad_button_6_label: "Pause Menu",

			player.controls.joypad_button_3_label: "Climb Up",
			player.controls.joypad_button_7_label: "Drop",
			player.controls.left_joystick_label: "Shimmy",
			player.controls.right_joystick_label: "Camera",
		}

