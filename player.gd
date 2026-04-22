class_name Player
extends CharacterBody3D

# https://youtu.be/l4uWdObc4do?si=-nYMz-615jmEC9qs&t=402
# https://www.youtube.com/watch?v=fBcKIxgJv-c&t=247s
@export var animation_tree: AnimationTree
@export var camera: Camera3D
@export var locomotion_forward_blend_path: String = "parameters/LocomotionStateMachine/Locomotion/ForwardBlend/blend_position"
@export var locomotion_strafe_blend_path: String = "parameters/LocomotionStateMachine/Locomotion/StrafeBlend/blend_position"
@export var locomotion_mode_path: String = "parameters/LocomotionStateMachine/Locomotion/LocomotionSwitch/blend_amount"
@export var locomotion_state_playback_path: String = "parameters/LocomotionStateMachine/playback"
@export var locomotion_state_name: String = "Locomotion"
@export var jumping_state_name: String = "Jumping"
@export var running_jump_state_name: String = "RunningJump"
@export var running_slide_state_name: String = "RunningSlide"
@export var transition_speed: float = 0.10
@export var turn_speed: float = 120.0

@export var jump_velocity: float = 4.5
@export var speed: float = 5.0

@onready var physical_bone_simulator: PhysicalBoneSimulator3D = $Pivot/RootMotion/PlayerModel/GeneralSkeleton/PhysicalBoneSimulator3D

var current_input_vector: Vector2 ## The current [Input] vector
var current_velocity: Vector2 ## The current velocity of the player (no verticality)
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var jump_queued: bool ## Is the "jump" state queued (button _just_ pressed)
var playback: AnimationNodeStateMachinePlayback:
	get:
		return animation_tree.get(locomotion_state_playback_path) as AnimationNodeStateMachinePlayback


func _ready() -> void:
	physical_bone_simulator.physical_bones_add_collision_exception(self)


func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	if is_on_floor():
		# Jump
		if Input.is_action_just_pressed("jump"):
			if velocity.length() > 0.1:
				begin_running_jump()
			else:
				begin_jump()


func _process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return
	
	# var new_delta = current_input_vector - current_velocity
	# if (new_delta.length() > transition_speed * delta):
	# 	new_delta = new_delta * transition_speed * delta
	# current_velocity += new_delta
	# animation_tree.set(locomotion_blend_path, current_velocity)

	# Sync player input and state machine's blend values
	var is_crouching = Input.is_action_just_pressed("crouch")
	var is_sprinting = Input.is_action_pressed("sprint")
	var is_strafing := Input.is_action_pressed("turn_camera")
	if is_crouching and is_sprinting:
		begin_running_slide()
	if is_strafing:
		animation_tree.set(locomotion_mode_path, 1.0)
		if is_sprinting:
			animation_tree.set(locomotion_strafe_blend_path, current_input_vector * 1.5)
			speed = 7.5
		else:
			animation_tree.set(locomotion_strafe_blend_path, current_input_vector)
			speed = 5.0
	else:
		animation_tree.set(locomotion_mode_path, 0.0)
		if is_sprinting:
			animation_tree.set(locomotion_forward_blend_path, current_input_vector * Vector2(1, 1.5))
			speed = 7.5
		else:
			animation_tree.set(locomotion_forward_blend_path, current_input_vector)
			speed = 5.0

	# DEBUGGING
	$Debug/List/Input/X.text = "X: "+  str(current_input_vector.x)
	$Debug/List/Input/Y.text = "Y: " + str(current_input_vector.y)
	$Debug/List/Velocity/X.text = "X: "+  str(velocity.x)
	$Debug/List/Velocity/Y.text = "Y: " + str(velocity.y)
	$Debug/List/Velocity/Z.text = "Z: " + str(velocity.z)
	$Debug/List/State/Value.text = str(playback.get_current_node())


func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	if not is_on_floor():
		velocity.y -= gravity * delta
		jump_queued = false
	
	if jump_queued:
		velocity.y += jump_velocity
		jump_queued = false

	var raw_input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var is_strafing := Input.is_action_pressed("turn_camera")

	if is_strafing:
		# Strafe mode: full 2D blend, camera controls facing direction
		var direction := (transform.basis * Vector3(raw_input.x, 0, raw_input.y)).normalized()
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			var cnv := to_local(global_position + velocity)
			current_input_vector = Vector2(cnv.x, -cnv.z).limit_length(1)
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
			current_input_vector = Vector2.ZERO
	else:
		# Free-move mode: A/D rotates player + turn animation, W/S = forward/backward
		if raw_input.x != 0.0:
			rotate(basis.y, deg_to_rad(-raw_input.x * turn_speed * delta))
		var forward_input := raw_input.y
		if abs(forward_input) > 0.01 or abs(raw_input.x) > 0.01:
			var direction := (transform.basis * Vector3(0, 0, forward_input)).normalized()
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			current_input_vector = Vector2(raw_input.x, -raw_input.y)
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
			current_input_vector = Vector2.ZERO
		look_at(global_position - transform.basis.z, Vector3.UP)

	move_and_slide()


func begin_jump():
	playback.travel(jumping_state_name)


func begin_running_jump():
	playback.travel(running_jump_state_name)


func begin_running_slide():
	playback.travel(running_slide_state_name)

func execute_jump_velocity():
	jump_queued = true
