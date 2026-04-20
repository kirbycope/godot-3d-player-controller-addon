class_name Player
extends CharacterBody3D
# https://youtu.be/l4uWdObc4do?si=-nYMz-615jmEC9qs&t=402
@export var animation_tree: AnimationTree;
@export var jump_velocity: float = 4.5
@export var locomotionBlendPath: String ## AnimationTree Path: Root > LocomotionStateMachine > Locomotion
@export var speed: float = 5.0
@export var transition_speed: float = 0.1

@onready var player_model: Node3D = $Pivot/RootMotion/PlayerModel

var current_input_vector: Vector2 ## The current [Input] vector
var current_velocity: Vector2 ## The current velocity of the player (no verticality)


func _process(delta: float) -> void:
	var new_delta = current_input_vector - current_velocity
	if (new_delta.length() > transition_speed * delta):
		new_delta = new_delta * transition_speed * delta
	current_velocity += new_delta
	animation_tree.set(locomotionBlendPath, current_velocity)

	# Sync player input and state machine's blend values
	#animation_tree.set(locomotionBlendPath, current_input_vector)

	# DEBUGGING
	$Debug/List/Input/X.text = "X: "+  str(current_input_vector.x)
	$Debug/List/Input/Y.text = "Y: " + str(current_input_vector.y)


func _ready() -> void:
	# If _this_ [Player] does not belong to the host...
	if not multiplayer.is_server():
		# Disable the `_process()` and `_physics_process()` functions
		set_process(false)


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	current_input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(current_input_vector.x, 0, current_input_vector.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
