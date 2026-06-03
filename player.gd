class_name Player
extends CharacterBody3D


#const SPEED = 5.0
#const JUMP_VELOCITY = 4.5
const MOTION_INTERPOLATE_SPEED: float = 10.0
const ROTATION_INTERPOLATE_SPEED: float = 10.0

@export var animation_tree: AnimationTree = get_node_or_null("AnimationTree")
@export var current_animation: int
@export var locomotion_blend_position_path: String = "parameters/LocomotionStateMachine/Locomotion/blend_position"

var motion := Vector2()
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


# https://github.com/godotengine/godot/blob/master/modules/gdscript/editor/script_templates/CharacterBody3D/basic_movement.gd#L10
#func _physics_process(delta: float) -> void:

	# Add the gravity.
	#if not is_on_floor():
	#	velocity += get_gravity() * delta

	# Handle jump.
	#if Input.is_action_just_pressed("ui_accept") and is_on_floor():
	#	velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	#var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	#var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	#var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	#if direction:
	#	velocity.x = direction.x * SPEED
	#	velocity.z = direction.z * SPEED
	#else:
	#	velocity.x = move_toward(velocity.x, 0, SPEED)
	#	velocity.z = move_toward(velocity.z, 0, SPEED)

	#move_and_slide()

	# If walking, send the input direction to "LocomotionStateMachine > Locomotion" blend position.
	#if animation_tree:
	#	animation_tree.set(locomotion_blend_position_path, input_dir)
	#else:
	#	push_warning("AnimationTree node not found. Please assign it to the 'animation_tree' variable using the Editor.")


# https://github.com/godotengine/tps-demo/blob/master/player/player.gd#L54
func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		apply_input(delta)
	else:
		animate(current_animation, delta)


# https://github.com/godotengine/tps-demo/blob/master/player/player.gd#L61
func animate(anim: int, _delta: float) -> void:
	current_animation = anim


# https://github.com/godotengine/tps-demo/blob/master/player/player.gd#L86
func apply_input(delta: float) -> void:
	motion = motion.lerp(player_input.motion, MOTION_INTERPOLATE_SPEED * delta)
	if animation_tree:
		animation_tree.set(locomotion_blend_position_path, motion)

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

	# If we're below -40, respawn (teleport to the initial position).
	if transform.origin.y < -40.0:
		transform.origin = initial_position
