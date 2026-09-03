class_name Skateboarding
extends NodeStateMachine

@export_category("Skateboarding Controls")
@export_group("Keyboard/Mouse Actions")
@export var keyboard_dismount_action: StringName = &"whistle"
@export var keyboard_jump_action: StringName = &"jump"
@export var keyboard_sprint_action: StringName = &"sprint"
@export var keyboard_kick_push_action: StringName = &"move_up"

@export_group("Controller/Touch Actions")
@export var pad_dismount_action: StringName = &"whistle"
@export var pad_jump_action: StringName = &"jump"
@export var pad_sprint_action: StringName = &"sprint"
@export var pad_kick_push_action: StringName = &"move_up"

const SKATEBOARD_ACCELERATION: float = 12.0
const SKATEBOARD_MAX_SPEED: float = 8.0
const SKATEBOARD_FRICTION: float = 5.0
const SKATEBOARD_KICK_PUSH_ACCELERATION: float = 3.5
const SKATEBOARD_KICK_PUSH_SPEED_THRESHOLD: float = 0.1
const SKATEBOARD_HIGH_SPEED_TURN_FACTOR: float = 0.65
const SKATEBOARD_SIDE_VELOCITY_FACTOR: float = 0.1
const SKATEBOARD_TURN_SPEED: float = 1.8


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if the player is not set or is paused/ragdolling
	if not player or player.is_paused or player.is_ragdolling: return
	if player.held_object and player.held_object.is_holding_object(): return

	# Dismount
	if event.is_action_pressed(action(keyboard_dismount_action, pad_dismount_action)) and not event.is_echo():
		player.state_machine.travel(state, States.STANDING)
		return

	var is_kick_pushing: bool = player.current_locomotion_node == "SkateboardingKickPush"

	# Jump
	if event.is_action_pressed(action(keyboard_jump_action, pad_jump_action)) \
	and not player.is_jumping \
	and not player.is_jump_queued \
	and not is_kick_pushing:
		player.is_jumping = true
		player.is_jump_queued = true

	# Kick push from (near) standstill
	if event.is_action_pressed(action(keyboard_kick_push_action, pad_kick_push_action)) \
	and not is_kick_pushing \
	and player.velocity.slide(player.up_direction).length() <= SKATEBOARD_KICK_PUSH_SPEED_THRESHOLD:
		player.locomotion_state.travel("SkateboardingKickPush")


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Do nothing if the player is not set
	if not player: return

	var target_motion: Vector2 = player.player_input.motion
	if Input.is_action_pressed(action(keyboard_sprint_action, pad_sprint_action)) and not player.is_exhausted and target_motion.y > 0.0:
		target_motion.y = 1.1
	var current_h_vel: Vector3 = player.velocity.slide(player.up_direction)
	var speed_ratio: float = clampf(current_h_vel.length() / SKATEBOARD_MAX_SPEED, 0.0, 1.0)
	var turn_speed_factor: float = 1.0 - ((1.0 - SKATEBOARD_HIGH_SPEED_TURN_FACTOR) * speed_ratio)
	var turn_amount: float = - target_motion.x * SKATEBOARD_TURN_SPEED * turn_speed_factor * delta
	if not is_zero_approx(turn_amount):
		player.orientation.basis = Basis(player.up_direction, turn_amount) \
				* player.orientation.basis

	var forward_dir: Vector3 = player.orientation.basis.z
	forward_dir = forward_dir.slide(player.up_direction)
	var has_forward_dir: bool = forward_dir.length_squared() > 0.001
	if has_forward_dir:
		forward_dir = forward_dir.normalized()
		var side_dir: Vector3 = player.orientation.basis.x.slide(player.up_direction)
		if side_dir.length_squared() > 0.001:
			side_dir = side_dir.normalized()
			var forward_velocity: Vector3 = forward_dir * current_h_vel.dot(forward_dir)
			var side_velocity: Vector3 = side_dir * current_h_vel.dot(side_dir)
			current_h_vel = forward_velocity + (side_velocity * SKATEBOARD_SIDE_VELOCITY_FACTOR)

	var is_kick_pushing: bool = player.current_locomotion_node == "SkateboardingKickPush"
	# Braking (held analog input) cancels the kick push
	if target_motion.y < 0.0 and is_kick_pushing:
		player.locomotion_state.start("SkateboardingLocomotion")
		is_kick_pushing = false

	var target_h_vel: Vector3 = forward_dir * SKATEBOARD_MAX_SPEED
	if is_kick_pushing and has_forward_dir:
		current_h_vel = current_h_vel.move_toward(target_h_vel, SKATEBOARD_KICK_PUSH_ACCELERATION * delta)
	elif target_motion.y > 0.0 and has_forward_dir:
		current_h_vel = current_h_vel.move_toward(target_h_vel, SKATEBOARD_ACCELERATION * delta)
	else:
		current_h_vel = current_h_vel.move_toward(Vector3.ZERO, SKATEBOARD_FRICTION * delta)

	var vertical_speed: float = player.velocity.dot(player.up_direction)
	vertical_speed += player.get_gravity().dot(player.up_direction) * 1.5 * delta
	player.velocity = current_h_vel + (player.up_direction * vertical_speed)
	player.animation_tree.set(Player.SKATEBOARDING_LOCOMOTION_BLEND_POSITION_PATH, target_motion.y)
	player.update_movement_and_rotation(delta)


## Start "skateboarding".
func start() -> void:
	super.start()
	# Flag the player as "skateboarding"
	player.is_skateboarding = true
	# Disable the separation ray shape while skateboarding
	if player.separation_ray_shape:
		player.separation_ray_shape.disabled = true
	# Show the skateboard
	if player.skateboard:
		player.skateboard.show()
	# Transition the locomotion state to Skateboarding
	player.locomotion_state.travel("SkateboardingLocomotion")
	# Prevent carrying upward velocity into grounded skateboarding movement.
	var vertical_speed: float = minf(player.velocity.dot(player.up_direction), 0.0)
	player.velocity = player.velocity.slide(player.up_direction) + (player.up_direction * vertical_speed)


## Stop "skateboarding".
func stop() -> void:
	super.stop()
	# Flag the player as not "skateboarding"
	player.is_skateboarding = false
	# Re-enable the separation ray shape when stopping skateboarding
	if player.separation_ray_shape:
		player.separation_ray_shape.disabled = false
	# Hide the skateboard
	if player.skateboard:
		player.skateboard.hide()


func get_contextual_controls(input_type: int) -> Dictionary:
	return {
		player.controls.left_joystick_label: "Steer",
		player.controls.right_joystick_label: "Camera",
		player.controls.joypad_button_3_label: "Ollie",
		player.controls.joypad_button_1_label: "Fast Push",
		player.controls.key_k_label if input_type == Controls.InputType.KEYBOARD_MOUSE else player.controls.joypad_button_12_label: "Dismount",
	}
