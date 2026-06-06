class_name Player
extends CharacterBody3D

const MOTION_INTERPOLATE_SPEED: float = 10.0
const ROTATION_INTERPOLATE_SPEED: float = 10.0
const LOCOMOTION_STATE_PLAYBACK_PATH: String = "parameters/LocomotionStateMachine/playback"
const BOW_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/BowLocomotion/blend_position"
const CROUCHING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/CrouchingLocomotion/blend_position"
const GREATSWORD_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/GreatSwordLocomotion/blend_position"
const SHIELD_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/ShieldLocomotion/blend_position"
const STANDING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/StandingLocomotion/blend_position"

@export var animation_tree: AnimationTree
@export var current_animation: int

var equipped_axe_1h: bool = false
var equipped_axe_2h: bool = false
var equipped_bow: bool = false
var equipped_dagger: bool = false
var equipped_shield: bool = false
var equipped_staff: bool = false
var equipped_sword_1h: bool = false
var equipped_sword_2h: bool = false
var is_crouching: bool = false
var is_falling: bool = false
var is_focusing: bool = false
var is_jumping: bool = false
var is_jump_queued: bool = false
var is_shooting: bool = false
var is_sliding: bool = false
var is_sprinting: bool = false
var orientation := Transform3D()
var root_motion := Transform3D()

@onready var player_model: Node3D = $PlayerModel
@onready var initial_position: Vector3 = transform.origin
@onready var player_input: InputSynchronizer = $InputSynchronizer
@onready var spring_arm: SpringArm3D = $SpringArm3D


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Pre-initialize orientation transform.
	orientation = player_model.global_transform
	orientation.origin = Vector3()

	# Ensure the AnimationTree is active so that root motion is applied in the first frame.
	animation_tree.active = true


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Toggle mouse capture
	if event.is_action_pressed("ui_cancel"):
		# Check if the mouse is currently captured
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# Set the mouse mode to visible to show the mouse cursor
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# The mouse must not be currently captured
		else:
			# Set the mouse mode to captured to hide the mouse cursor
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# https://github.com/godotengine/tps-demo/blob/master/player/player.gd#L54
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Apply player input to control the character and update the animation state.
	apply_input(delta)

	# If we're below -40, respawn (teleport to the initial position).
	if transform.origin.y < -40.0:
		transform.origin = initial_position

	# Track if the player is "falling"
	is_falling = animation_tree.get(LOCOMOTION_STATE_PLAYBACK_PATH).get_current_node() == "Falling"

	# Stop "jumping" if player is "falling".
	if is_jumping and is_falling:
		is_jumping = false

	# Stop "falling" when player lands on the floor.
	if is_falling and is_on_floor():
		is_falling = false

	# Stop "sliding" when the animation finishes.
	var was_sliding := is_sliding
	is_sliding = animation_tree.get(LOCOMOTION_STATE_PLAYBACK_PATH).get_current_node() == "RunningSlide"
	if was_sliding and not is_sliding:
		is_sliding = false


# https://github.com/godotengine/tps-demo/blob/master/player/player.gd#L86
func apply_input(delta: float) -> void:
	# Get the target motion from the synchronized input.
	var target_motion: Vector2 = player_input.motion

	# Smoothly interpolate the target_motion for more gradual changes in animation blending and rotation.
	target_motion = target_motion.lerp(target_motion, MOTION_INTERPOLATE_SPEED * delta)
	
	# Shoot { Microsoft: 🅁T, Nintendo: 🅁L, Sony: 🅁2, Keyboard: [Left Mouse Button] } 
	is_shooting = Input.is_action_pressed("shoot")

	# Crouch { Console: Left ⬤, Keyboard: [Control] }.
	is_crouching = Input.is_action_pressed("crouch") and is_on_floor() and not is_sliding and not is_sprinting

	# Focus { Microsoft: 🄻T, Nintendo: ZL, Sony: L2, Keyboard: [Right Mouse Button] }.
	is_focusing = Input.is_action_pressed("focus")

	# Jump { Microsoft: Ⓐ, Nintendo: Ⓐ, Sony: Ⓞ, Keyboard: [Space] }.
	if is_on_floor() \
	and Input.is_action_just_pressed("jump") \
	and not is_jump_queued:
		if target_motion.y > 0.0:
			animation_tree.get(LOCOMOTION_STATE_PLAYBACK_PATH).travel("RunningJump")
		else:
			animation_tree.get(LOCOMOTION_STATE_PLAYBACK_PATH).travel("JumpingUp")
		is_jump_queued = true

	# Sprint { Microsoft: Ⓑ, Nintendo: Ⓐ, Sony: Ⓞ, Keyboard: [Shift] }.
	if is_on_floor() \
	and Input.is_action_pressed("sprint") \
	and not is_crouching \
	and not is_jump_queued \
	and not is_jumping \
	and not is_sliding \
	and (target_motion.y > 0.0 if is_focusing else target_motion.length() > 0.0):
		if is_focusing:
			target_motion.y *= 1.5
			target_motion.x *= 0.5 # reduce strafe blend by 50% when sprinting so the blend favors the forward direction
		else:
			target_motion *= 1.5
		is_sprinting = true
	else:
		is_sprinting = false

	# Slide (Crouch while Sprinting)
	if is_sprinting \
	and Input.is_action_just_pressed("crouch") \
	and not is_sliding:
		animation_tree.get(LOCOMOTION_STATE_PLAYBACK_PATH).travel("RunningSlide")
		is_sliding = true

	# Handle movement is strafing
	if is_focusing:

		# Rotate to face the camera direction when focusing
		var camera_basis := spring_arm.global_transform.basis
		var camera_forward := -camera_basis.z
		camera_forward.y = 0.0
		if camera_forward.length_squared() > 0.001:
			camera_forward = camera_forward.normalized()
			var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
			var q_to: Quaternion = Basis.looking_at(-camera_forward).get_rotation_quaternion()
			orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))
		if is_crouching:
			animation_tree.set(CROUCHING_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
		else:
			if equipped_bow:
				animation_tree.set(BOW_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif equipped_axe_1h or equipped_dagger or equipped_shield or equipped_sword_1h:
				animation_tree.set(SHIELD_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif equipped_axe_2h or equipped_sword_2h:
				animation_tree.set(GREATSWORD_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			else:
				animation_tree.set(STANDING_LOCOMOTION_BLEND_POSITION_PATH, target_motion)

	# Handle movement when not strafing
	else:
		# Use camera-relative direction for target_motion direction
		var camera_basis := spring_arm.global_transform.basis
		var target_dir := camera_basis * Vector3(target_motion.x, 0.0, -target_motion.y)
		target_dir.y = 0.0
		if target_dir.length_squared() > 0.001:
			target_dir = target_dir.normalized()
			var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
			var q_to: Quaternion = Basis.looking_at(-target_dir).get_rotation_quaternion()
			orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))
		var anim_blend := Vector2(0.0, target_motion.length())
		if is_crouching:
			animation_tree.set(CROUCHING_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
		else:
			if equipped_bow:
				animation_tree.set(BOW_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			elif equipped_axe_1h or equipped_dagger or equipped_shield or equipped_sword_1h:
				animation_tree.set(SHIELD_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			elif equipped_axe_2h or equipped_sword_2h:
				animation_tree.set(GREATSWORD_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			else:
				animation_tree.set(STANDING_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)

	root_motion = Transform3D(animation_tree.get_root_motion_rotation(), animation_tree.get_root_motion_position())

	orientation *= root_motion

	var h_velocity: Vector3 = orientation.origin / delta

	# Influence of root motion is removed when in the air, and movement is instead based on the input direction to allow for more player control while jumping and falling.
	if is_jumping or is_falling:
		var camera_basis := spring_arm.global_transform.basis
		var target_dir := camera_basis * Vector3(target_motion.x, 0.0, -target_motion.y)
		target_dir.y = 0.0
		
		var current_h_vel := Vector3(velocity.x, 0.0, velocity.z)
		var current_speed := current_h_vel.length()
		var air_speed_cap := max(current_speed, 5.0)
		var target_h_vel = target_dir * air_speed_cap
		
		# Slowly lerp to target air speed to preserve momentum
		h_velocity = current_h_vel.lerp(target_h_vel, 3.0 * delta)

	velocity.x = h_velocity.x
	velocity.z = h_velocity.z
	velocity += get_gravity() * delta
	set_velocity(velocity)
	set_up_direction(Vector3.UP)
	move_and_slide()

	orientation.origin = Vector3() # Clear accumulated root motion displacement (was applied to speed).
	orientation = orientation.orthonormalized() # Orthonormalize orientation.

	player_model.global_transform.basis = orientation.basis


## Called by the animation(s) using "Call Method Track" to execute the jump logic at the right time. 
func execute_jump() -> void:
	velocity.y = 5.0
	is_jump_queued = false
	is_jumping = true
