class_name Surfing
extends NodeStateMachine
## Shield surfing, as in Breath of the Wild and Tears of the Kingdom: with a shield on the left arm, hold Focus (ZL) in
## the air, off a jump, a fall or the glider, and press Action (A), and the Player rides the shield down the slope
## ([method Player.try_shield_surf]). A downhill speeds it up, flat ground slows it and an uphill stops it; the stick
## steers and Jump hops without getting off. It ends by Cancel, by coming to a stop, or on running into a wall. The
## pose is the skateboard's, crouching lower the faster it goes, and the shield goes under the feet
## ([member Player.is_shield_surfing], replicated, so every peer sees it).

const SKATEBOARDING_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/SkateboardingLocomotion/blend_position"

@export_category("Surfing Controls")
@export_group("Keyboard/Mouse Actions")
@export var keyboard_stop_action: StringName = &"crouch" ## Steps off the shield.
@export var keyboard_jump_action: StringName = &"jump" ## Hops, still on the shield.

@export_group("Controller/Touch Actions")
@export var pad_stop_action: StringName = &"sprint" ## Steps off the shield: B, as in the games.
@export var pad_jump_action: StringName = &"jump"

@export_group("Surf Physics")
@export_range(0.0, 1.0, 0.01) var friction: float = 0.12 ## The shield's sliding friction on the ground: this times gravity's push into the slope is the speed it loses every second. A gentle slope, steeper than about 7 degrees, still speeds it up.
@export var max_speed: float = 18.0 ## m/s it never goes past, however steep.
@export var turn_rate: float = 2.2 ## How fast the stick turns the ride, in radians per second.
@export var jump_speed: float = 5.0 ## Upward speed of a hop off the shield (m/s).
@export var stop_speed: float = 1.0 ## Slower than this on the ground, the ride is over.
@export var stop_time: float = 0.35 ## Seconds it has to stay that slow before it ends, so the dip at the bottom of a slope does not.
@export var launch_speed: float = 3.0 ## Speed a ride starting from a standstill in the air gets along the way the Player faces.

var _slow_for: float = 0.0
var _speed: float = 0.0 ## The ride's speed along the ground, kept by the ride rather than read back from the body.
var _heading: Vector3 = Vector3.ZERO
var _grounded: bool = false ## On the ground last step, so the ride's own speed and heading are current.
var _fall_speed: float = 0.0 ## How fast it was coming down in the air, for a landing too hard to ride out.
var _saved_constant_speed: bool = true


func _input(event: InputEvent) -> void:
	if not player or player.is_paused or player.is_typing or player.is_ragdolling: return

	if event.is_action_pressed(action(keyboard_stop_action, pad_stop_action)) and not event.is_echo():
		_end()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(action(keyboard_jump_action, pad_jump_action)) and not event.is_echo() and player.is_on_floor():
		player.velocity = _heading * _speed + player.up_direction * jump_speed
		_grounded = false
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not player: return
	if player.get_surf_shield() == null or player.is_swimming:
		_end()
		return

	var up: Vector3 = player.up_direction
	var gravity: Vector3 = player.get_gravity()
	var velocity: Vector3 = player.velocity
	var on_floor: bool = player.is_on_floor()
	if on_floor:
		if _fall_speed >= player.lethal_fall_speed:
			player.state_machine.travel(state, States.RAGDOLLING)
			return
		_fall_speed = 0.0
		var normal: Vector3 = player.get_floor_normal()
		# The ride keeps its own speed and heading on the ground: the body hands its velocity back with the part into
		# the slope gone, and laying that on the slope again every step bled a sixth of the speed away each second.
		# Landing, it takes the body's.
		var along: Vector3 = (_heading * _speed if _grounded else velocity).slide(normal)
		# Down the slope, gravity's share along it; against the ride, friction in proportion to how hard it presses in.
		along += gravity.slide(normal) * delta
		var speed: float = along.length()
		speed = clampf(speed - friction * absf(gravity.dot(normal)) * delta, 0.0, max_speed)
		var heading: Vector3 = along.normalized() if along.length_squared() > 1e-6 else player.get_facing_direction().slide(normal).normalized()
		heading = _steer(heading, normal, delta)
		velocity = heading * speed
		_heading = heading
		_speed = speed
		_grounded = true
		# Too slow on ground too gentle to get it going again: the ride is over. On a slope it only turns and runs
		# back down, as a stall going uphill does.
		var rolls: bool = gravity.slide(normal).length() > friction * absf(gravity.dot(normal))
		_slow_for = _slow_for + delta if speed < stop_speed and not rolls else 0.0
		if _slow_for >= stop_time or _ran_into_a_wall(heading):
			_end()
			return
	else:
		if _grounded:
			velocity = _heading * _speed + up * maxf(velocity.dot(up), 0.0) # off a crest or a hop, at the ride's speed
		_grounded = false
		velocity += gravity * delta
		_fall_speed = -velocity.dot(up)
		var flat: Vector3 = velocity.slide(up)
		if flat.length_squared() > 1e-4:
			var turned: Vector3 = _steer(flat.normalized(), up, delta * 0.5)
			velocity = turned * flat.length() + up * velocity.dot(up)

	player.velocity = velocity
	var flat_velocity: Vector3 = velocity.slide(up)
	if flat_velocity.length_squared() > 0.01:
		player.turn_model_toward_direction(flat_velocity, delta)
	# Tall at a crawl, the cruising stance, then lower as it picks up speed.
	var speed_share: float = clampf(flat_velocity.length() / max_speed, 0.0, 1.0)
	player.animation_tree.set(SKATEBOARDING_BLEND_POSITION_PATH, lerpf(0.4, 1.1, sqrt(speed_share)))
	player.update_movement_and_rotation(delta)


## [param heading] turned toward where the stick points, relative to the camera and along the surface under
## [param normal], by at most [member turn_rate] this step.
func _steer(heading: Vector3, normal: Vector3, delta: float) -> Vector3:
	var motion: Vector2 = player.player_input.motion
	if motion.length_squared() < 0.01:
		return heading
	var camera_basis: Basis = player.spring_arm.global_transform.basis
	var wish: Vector3 = (camera_basis * Vector3(motion.x, 0.0, -motion.y)).slide(normal)
	if wish.length_squared() < 1e-6:
		return heading
	wish = wish.normalized()
	var angle: float = heading.signed_angle_to(wish, normal)
	return heading.rotated(normal, clampf(angle, -turn_rate * delta, turn_rate * delta)).normalized()


## True when the move just made ran the ride into something standing in its way.
func _ran_into_a_wall(heading: Vector3) -> bool:
	for i: int in player.get_slide_collision_count():
		var normal: Vector3 = player.get_slide_collision(i).get_normal()
		if absf(normal.dot(player.up_direction)) < 0.3 and heading.dot(normal) < -0.7:
			return true
	return false


func _end() -> void:
	player.state_machine.travel(state, States.STANDING if player.is_on_floor() else States.FALLING)


## Start "surfing": on the shield, in the skateboard's stance, riding the ground at whatever speed it had.
func start() -> void:
	super.start()
	player.is_shield_surfing = true
	_slow_for = 0.0
	_grounded = false
	_fall_speed = maxf(-player.velocity.dot(player.up_direction), 0.0)
	_saved_constant_speed = player.floor_constant_speed
	player.floor_constant_speed = false # the speed along a slope is the ride's own, not walking's
	var flat: Vector3 = player.velocity.slide(player.up_direction)
	if flat.length() < launch_speed:
		player.velocity += player.get_facing_direction().slide(player.up_direction).normalized() * (launch_speed - flat.length())
	player.locomotion_state.start("SkateboardingLocomotion")


## Stop "surfing": the shield back on the arm.
func stop() -> void:
	super.stop()
	player.is_shield_surfing = false
	player.floor_constant_speed = _saved_constant_speed


func get_contextual_controls(input_type: int) -> Dictionary:
	return {
		player.controls.left_joystick_label: "Steer",
		player.controls.right_joystick_label: "Camera",
		player.controls.action_label(&"jump", player.controls.joypad_button_3_label): "Jump",
		player.controls.joypad_button_7_label if input_type == Controls.InputType.KEYBOARD_MOUSE else player.controls.action_label(&"sprint", player.controls.joypad_button_0_label): "Get Off",
	}
