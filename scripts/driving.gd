class_name Driving
extends NodeStateMachine
## Seats the Player in a vehicle and forwards drive inputs to it; the drivetrain belongs to the vehicle.
##
## Vehicle contract (duck typed, the addon does not depend on project vehicles):
## [code]set_driver(player)[/code] is called by the vehicle on enter and by this state on exit;
## [code]set_drive_input(accelerate: bool, brake: bool, handbrake: bool, steer: float)[/code]
## is called every physics frame while the Player is seated. Optional "DriverSeat", "ExitCar"
## and "EnterCar" markers position the Player.

@export_category("Driving Controls")
@export_group("Keyboard/Mouse Actions")
@export var keyboard_accelerate_action: StringName = &"jump"
@export var keyboard_brake_action: StringName = &"sprint"
@export var keyboard_handbrake_action: StringName = &"throw"
@export var keyboard_exit_action: StringName = &"action"

@export_group("Controller/Touch Actions")
@export var pad_accelerate_action: StringName = &"shoot"
@export var pad_brake_action: StringName = &"focus"
@export var pad_handbrake_action: StringName = &"throw"
@export var pad_exit_action: StringName = &"jump"

const BAIL_OUT_SPEED: float = 2.0 ## Above this speed exiting skips the door animation.

var _driver_seat: Node3D ## The vehicle's "DriverSeat" marker, cached on start.


func _input(event: InputEvent) -> void:
	if player == null or player.is_paused or player.is_ragdolling \
			or player.is_entering_vehicle or player.is_exiting_vehicle \
			or not event.is_action_pressed(action(keyboard_exit_action, pad_exit_action)):
		return

	var car: RigidBody3D = player.is_driving_in as RigidBody3D
	if car and car.linear_velocity.length() > BAIL_OUT_SPEED:
		var exit_marker: Node3D = car.get_node_or_null("ExitCar") as Node3D
		if exit_marker == null:
			exit_marker = car.get_node_or_null("EnterCar") as Node3D
		if exit_marker:
			player.global_position = exit_marker.global_position
		if car.get_parent() and player.get_parent() != car.get_parent():
			player.reparent(car.get_parent())
		player.state_machine.travel(state, NodeStateMachine.States.STANDING)
	else:
		player.is_exiting_vehicle = true
		if player.is_driving_in.has_method("set_driver"):
			player.is_driving_in.call("set_driver", null)


## Seats the Player once the entering animation ends; stands up once the exiting animation ends.
func _on_locomotion_node_changed(state_path: String) -> void:
	if process_mode != Node.PROCESS_MODE_INHERIT:
		return
	if player.is_entering_vehicle and state_path != "EnteringCar":
		player.is_entering_vehicle = false
	elif player.is_exiting_vehicle and state_path != "ExitingCar":
		player.state_machine.travel(state, NodeStateMachine.States.STANDING)


func _physics_process(_delta: float) -> void:
	if player == null or player.is_driving_in == null or player.is_entering_vehicle or player.is_exiting_vehicle:
		return

	if _driver_seat:
		player.global_position = _driver_seat.global_position
		player.orientation = _driver_seat.global_transform
		player.orientation.origin = Vector3.ZERO
		player.player_model.global_transform = _driver_seat.global_transform

	if player.is_driving_in.has_method("set_drive_input"):
		var blocked: bool = player.is_paused or player.is_ragdolling
		player.is_driving_in.call("set_drive_input",
			not blocked and Input.is_action_pressed(action(keyboard_accelerate_action, pad_accelerate_action)),
			not blocked and Input.is_action_pressed(action(keyboard_brake_action, pad_brake_action)),
			not blocked and Input.is_action_pressed(action(keyboard_handbrake_action, pad_handbrake_action)),
			0.0 if blocked else Input.get_axis("move_right", "move_left"))


## Start "driving".
func start() -> void:
	super.start()
	player.is_driving = true
	player.is_entering_vehicle = true
	player.is_exiting_vehicle = false
	_driver_seat = player.is_driving_in.get_node_or_null("DriverSeat") as Node3D
	player.locomotion_state.start("EnteringCar")
	player.collision_shape.disabled = true
	player.crosshair.hide()


## Stop "driving".
func stop() -> void:
	super.stop()
	player.is_driving = false
	if player.is_driving_in and player.is_driving_in.has_method("set_driver"):
		player.is_driving_in.call("set_driver", null)
	player.is_driving_in = null
	_driver_seat = null
	player.is_entering_vehicle = false
	player.is_exiting_vehicle = false
	player.collision_shape.disabled = false
	player.crosshair.show()


func get_contextual_controls(input_type: int) -> Dictionary:
	var controls: Dictionary = {
		player.controls.joypad_button_4_label: "Perspective",
		player.controls.joypad_button_15_label: "Screenshot",
		player.controls.joypad_button_6_label: "Pause Menu",
		player.controls.joypad_button_10_label: "Handbrake",
		player.controls.joypad_button_13_label: "Prev\nStation",
		player.controls.joypad_button_14_label: "Next\nStation",
		player.controls.left_joystick_label: "Steer",
		player.controls.right_joystick_label: "Camera",
	}
	if input_type == player.controls.InputType.KEYBOARD_MOUSE:
		controls[player.controls.joypad_button_3_label] = "Accelerate"
		controls[player.controls.joypad_button_1_label] = "Brake"
		controls[player.controls.joypad_button_0_label] = "Exit"
		controls[player.controls.key_j_label] = "Prev\nStation"
		controls[player.controls.key_l_label] = "Next\nStation"
	else:
		controls[player.controls.joypad_axis_4_plus_label] = "Brake"
		controls[player.controls.joypad_axis_5_plus_label] = "Accelerate"
		controls[player.controls.joypad_button_3_label] = "Exit"
	return controls
