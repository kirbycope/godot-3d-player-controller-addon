class_name Player
extends CharacterBody3D

@export var animation_tree: AnimationTree;
@export var jump_velocity: float = 4.5
@export var locomotionBlendPath: String ## AnimationTree Path: Root > LocomotionStateMachine > Locomotion
@export var speed: float = 5.0
@export var transition_speed: float = 0.1

@onready var player_model: Node3D = $Pivot/RootMotion/PlayerModel

var input_dir: Vector2 ## The current [Input] vector


func _process(delta: float) -> void:
	# Sync player input and state machine's blend values
	animation_tree.set(locomotionBlendPath, input_dir)

	# DEBUGGING
	$Debug/List/Input/X.text = "X: "+  str(input_dir.x)
	$Debug/List/Input/Y.text = "Y: " + str(input_dir.y)


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
	input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
