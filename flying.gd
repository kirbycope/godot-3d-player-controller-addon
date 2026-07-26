class_name Flying
extends NodeStateMachine

const DOUBLE_TAP_TIME_MS: int = 300

@export var down_action: StringName = &"action"
@export var stop_action: StringName = &"action" ## Requires a double-press
@export var up_action: StringName = &"jump"

var _last_crouch_press_time: int = 0
var _this_state := NodeStateMachine.States.FLYING


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Stop flying if double-press crouch
	if event.is_action_pressed(stop_action) and not event.is_echo():
		var current_time := Time.get_ticks_msec()
		if current_time - _last_crouch_press_time <= DOUBLE_TAP_TIME_MS:
			if player.is_on_floor():
				player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
			else:
				player.state_machine.travel(_this_state, NodeStateMachine.States.FALLING)
			_last_crouch_press_time = 0
			return
		else:
			_last_crouch_press_time = current_time


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	var up_dir: Vector3 = player.up_direction.normalized()

	# Check if the player has reached the floor
	if player.is_on_floor():
		# Start "standing"
		player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
		return

	# While flying, movement is driven relative to camera / input
	var target_motion: Vector2 = player.player_input.motion

	# Update sprint flag and locomotion blend position in FlyingLocomotion
	player.is_sprinting = Input.is_action_pressed("sprint")
	var speed_blend: float = target_motion.length()
	if player.is_sprinting:
		speed_blend *= 1.5
	player.animation_tree.set(Player.FLYING_LOCOMOTION_BLEND_POSITION_PATH, speed_blend)

	# Calculate camera-relative movement direction projected onto up_dir plane
	var camera_basis: Basis = player.spring_arm.global_transform.basis
	var target_dir: Vector3 = camera_basis * Vector3(target_motion.x, 0.0, -target_motion.y)
	target_dir = target_dir.slide(up_dir)

	if target_dir.length_squared() > 0.001 and not player.is_firing_arrow:
		target_dir = target_dir.normalized()
		var q_from: Quaternion = player.orientation.basis.get_rotation_quaternion()
		var q_to: Quaternion = Basis.looking_at(-target_dir, up_dir).get_rotation_quaternion()
		player.orientation.basis = Basis(q_from.slerp(q_to, delta * player.rotation_interpolate_speed))

	# Horizontal speed
	var fly_speed: float = 8.0
	if player.is_sprinting:
		fly_speed = 14.0

	var h_velocity: Vector3 = Vector3.ZERO
	if target_dir.length_squared() > 0.001:
		h_velocity = target_dir.normalized() * fly_speed * (speed_blend / (1.5 if player.is_sprinting else 1.0))

	# Vertical control along player.up_direction (jump to fly upward along up_dir, crouch to fly downward along -up_dir)
	var v_speed: float = 0.0
	if Input.is_action_pressed(up_action):
		v_speed = 6.0
	elif Input.is_action_pressed(down_action):
		v_speed = -6.0

	player.velocity = h_velocity + (up_dir * v_speed)
	player.update_movement_and_rotation(delta)


## Start "flying".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
	# Flag the player as "flying"
	player.is_flying = true
	# Flag the player as not jumping or falling
	player.is_jumping = false
	player.is_falling = false
	# Teleport locomotion playback into the FlyingLocomotion animation state.
	player.locomotion_state.start("FlyingLocomotion")


## Stop "flying".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "flying"
	player.is_flying = false
