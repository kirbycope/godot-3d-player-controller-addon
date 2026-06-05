class_name Player
extends CharacterBody3D

const MOTION_INTERPOLATE_SPEED: float = 10.0
const ROTATION_INTERPOLATE_SPEED: float = 10.0

@export var animation_tree: AnimationTree = get_node_or_null("AnimationTree")
@export var current_animation: int
@export var locomotion_blend_position_path: String = "parameters/LocomotionStateMachine/Locomotion/blend_position"
@export var locomotion_state_playback_path: String = "parameters/LocomotionStateMachine/playback"
var is_falling: bool = false
var is_jumping: bool = false
var is_jump_queued: bool = false
var is_sprinting: bool = false

#var motion := Vector2()
var orientation := Transform3D()
var root_motion := Transform3D()

@onready var player_model: Node3D = $PlayerModel
@onready var initial_position: Vector3 = transform.origin
@onready var player_input: InputSynchronizer = $InputSynchronizer


func _ready() -> void:
	# Pre-initialize orientation transform.
	orientation = player_model.global_transform
	orientation.origin = Vector3()
	if animation_tree:
		animation_tree.active = true


# https://github.com/godotengine/tps-demo/blob/master/player/player.gd#L54
func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		apply_input(delta)
	else:
		animate(current_animation, delta)

	# If we're below -40, respawn (teleport to the initial position).
	if transform.origin.y < -40.0:
		transform.origin = initial_position

	# Track if the player is "falling"
	is_falling = animation_tree.get(locomotion_state_playback_path).get_current_node() == "Falling"

	# Stop "jumping" if player is "falling".
	if is_jumping and is_falling:
		is_jumping = false

	# Stop "falling" when player lands on the floor.
	if is_falling and is_on_floor():
		is_falling = false


# https://github.com/godotengine/tps-demo/blob/master/player/player.gd#L61
func animate(anim: int, _delta: float) -> void:
	current_animation = anim
	# TODO: Finish


# https://github.com/godotengine/tps-demo/blob/master/player/player.gd#L86
func apply_input(delta: float) -> void:
	var target_motion: Vector2 = player_input.motion

	# Jumping { Microsoft: Ⓐ, Nintendo: Ⓐ, Sony: Ⓞ, Keyboard: [Space] }.
	if is_on_floor() \
	and Input.is_action_just_pressed("jump") \
	and not is_jump_queued:
		if target_motion.y > 0.0:
			animation_tree.get(locomotion_state_playback_path).travel("RunningJump")
		else:
			animation_tree.get(locomotion_state_playback_path).travel("JumpingUp")
		is_jump_queued = true

	# Sprint { Microsoft: Ⓑ, Nintendo: Ⓐ, Sony: Ⓞ, Keyboard: [Shift] }.
	if is_on_floor() \
	and Input.is_action_pressed("sprint") \
	and not is_jump_queued \
	and not is_jumping \
	and target_motion.y > 0.0:
		target_motion.y *= 1.5 # increase forward blend by 50% when sprinting
		target_motion.x *= 0.5 # reduce strafe blend by 50% when sprinting
		is_sprinting = true
	else:
		is_sprinting = false

	target_motion = target_motion.lerp(target_motion, MOTION_INTERPOLATE_SPEED * delta)

	if animation_tree:
		# Send the movement input to the AnimationTree to blend between the "Locomotion" animations.
		animation_tree.set(locomotion_blend_position_path, target_motion)

	root_motion = Transform3D(animation_tree.get_root_motion_rotation(), animation_tree.get_root_motion_position())

	# Apply root motion to orientation.
	orientation *= root_motion

	var h_velocity: Vector3 = orientation.origin / delta
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
