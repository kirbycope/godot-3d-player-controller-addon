class_name Sitting
extends NodeStateMachine

@export_category("Sitting Controls")
@export_group("Keyboard/Mouse Actions")
@export var keyboard_stand_action: StringName = &"jump"

@export_group("Controller/Touch Actions")
@export var pad_stand_action: StringName = &"jump"

var _this_state := NodeStateMachine.States.SITTING


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if the player is not set or is paused/ragdolling
	if not player or player.is_paused or player.is_ragdolling: return

	var input_type = player.controls.current_input_type if player and player.controls else 0
	var current_stand_action = keyboard_stand_action if input_type == 0 else pad_stand_action

	# Stand up
	if event.is_action_pressed(current_stand_action):
		if player.state_machine:
			player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)


## Start "sitting".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
	# Flag the player as "sitting"
	player.is_sitting = true


## Stop "sitting".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "sitting"
	player.is_sitting = false


func get_contextual_controls(input_type: int) -> Dictionary:
	if not player or not player.controls: return {}

	return {
		player.controls.joypad_button_4_label: "Perspective",
		player.controls.joypad_button_15_label: "Screenshot",
		player.controls.joypad_button_6_label: "Pause Menu",

		player.controls.joypad_button_3_label: "Stand Up",
		player.controls.right_joystick_label: "Camera",
	}
