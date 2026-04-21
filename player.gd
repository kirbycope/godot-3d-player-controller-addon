class_name Player
extends CharacterBody3D

# https://youtu.be/l4uWdObc4do?si=-nYMz-615jmEC9qs&t=402
# https://www.youtube.com/watch?v=fBcKIxgJv-c&t=247s
@export var animation_tree: AnimationTree
@export var camera: Camera3D
@export var locomotion_blend_path: String = "parameters/LocomotionStateMachine/Locomotion/blend_position"
@export var locomotion_state_playback_path: String = "parameters/LocomotionStateMachine/playback"
@export var jumping_state_name: String = "Jumping"
@export var falling_state_name: String = "Falling"
@export var running_jump_state_name: String = "RunningJump"
@export var transition_speed: float = 0.10
@export var walking_state_name: String = "Locomotion"

@export var jump_velocity: float = 4.5
@export var speed: float = 5.0

var current_input_vector: Vector2 ## The current [Input] vector
var current_velocity: Vector2 ## The current velocity of the player (no verticality)
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var falling: bool ## Is the player "falling"?
var jump_queued: bool ## Is the "jump" state queued (button _just_ pressed)


func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Jump
	if is_on_floor() \
	and Input.is_action_just_pressed("ui_accept"):
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
	animation_tree.set(locomotion_blend_path, current_input_vector)

	# DEBUGGING
	$Debug/List/Input/X.text = "X: "+  str(current_input_vector.x)
	$Debug/List/Input/Y.text = "Y: " + str(current_input_vector.y)
	$Debug/List/Velocity/X.text = "X: "+  str(velocity.x)
	$Debug/List/Velocity/Y.text = "Y: " + str(velocity.y)
	$Debug/List/Velocity/Z.text = "Z: " + str(velocity.z)
	$Debug/List/State/Value.text = str(animation_tree.get(locomotion_state_playback_path).get_current_node())


func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Add the gravity.
	#if not is_on_floor():
	#	velocity += get_gravity() * delta

	# Handle jump.
	#if Input.is_action_just_pressed("ui_accept") and is_on_floor():
	#	velocity.y = jump_velocity


	if !is_on_floor():
		velocity.y -= gravity * delta
		jump_queued = false
		if !falling:
			falling = true
			var playback = animation_tree.get(locomotion_state_playback_path) as AnimationNodeStateMachinePlayback
			playback.travel(falling_state_name)
	else:
		if falling:
			falling = false
			var playback = animation_tree.get(locomotion_state_playback_path) as AnimationNodeStateMachinePlayback
			playback.travel(walking_state_name)

	# Putting it after the falling handler makes sure that the transition doesn't
	# automatically force it into a falling animation instead of letting the jump animation
	# naturally finish.
	
	if jump_queued:
		velocity.y = jump_velocity
		jump_queued = false
		falling = true

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	current_input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(current_input_vector.x, 0, current_input_vector.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		var current_normalized_velocity = to_local(global_position + velocity)
		current_input_vector = Vector2(current_normalized_velocity.x, -current_normalized_velocity.z).limit_length(1)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		current_input_vector = Vector2.ZERO

	#rotation_degrees.y = camera.rotation_degrees.y

	move_and_slide()


func begin_jump():
	var playback = animation_tree.get(locomotion_state_playback_path) as AnimationNodeStateMachinePlayback
	playback.travel(jumping_state_name)


func begin_running_jump():
	var playback = animation_tree.get(locomotion_state_playback_path) as AnimationNodeStateMachinePlayback
	playback.travel(running_jump_state_name)


func execute_jump_velocity():
	jump_queued = true
