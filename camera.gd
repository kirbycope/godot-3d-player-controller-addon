extends Camera3D

enum Perspective {
	FIRST_PERSON,
	SECOND_PERSON,
	THIRD_PERSON,
}

@export var camera_base: Node3D ## Reference to the $CameraBase
@export var look_sensitivity_controller := 150.0 ## Controller look sensitivity
@export var look_sensitivity_mouse := 0.2 ## Mouse look sensitivity
@export var perspective: Perspective = Perspective.THIRD_PERSON ## The current camera perspective
@export var player: Player ## Reference to the [Player] node
@export var player_model: Node3D ## Reference to the player's model (`Pivot/RootMotion/PlayerModel`)

var camera_pitch := 0.0 ## Camera pitch (up/down) rotation in degrees


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Have the SpringArm exclude the player from its raycast to prevent issues when the collision shape changes
	var spring_arm := get_parent() as SpringArm3D
	if spring_arm and player:
		spring_arm.add_excluded_object(player.get_rid())


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Capture mouse input when "strafing"
	if player.is_strafing:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Check for mouse motion
	if event is InputEventMouseMotion:
		# Check if the mouse is captured or hidden -> Rotate camera
		if Input.get_mouse_mode() in [Input.MOUSE_MODE_CAPTURED, Input.MOUSE_MODE_HIDDEN]:
			#camera_rotate_by_mouse(event)
			pass


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Check for controller input
	if Input.get_vector("look_left", "look_right", "look_up", "look_down") != Vector2.ZERO:
		camera_rotate_by_controller(delta)


## Rotate camera using the controller.
func camera_rotate_by_controller(delta: float) -> void:
	var look_input := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	# Clamp the camera rotation (to prevent over rotating) and apply sensitivity
	camera_pitch = clamp(camera_pitch - look_input.y * look_sensitivity_controller * delta, -80, 90)
	# Apply pitch to the camera pivot (or this camera if pivot is not assigned)
	camera_base.rotation_degrees.x = -camera_pitch
	# Define the new rotation in the y direction based on the look input and sensitivity
	var new_rotation_y := -look_input.x * look_sensitivity_controller * delta
	# Rotate the player along the y-axis by the new rotation value
	player.rotate(player.basis.y, deg_to_rad(new_rotation_y))
	# If the player is strafing...
	if player.is_strafing:
		# Rotate the camera around the player
		camera_base.rotate_y(deg_to_rad(new_rotation_y))


## Rotate camera using the mouse motion.
func camera_rotate_by_mouse(event: InputEventMouseMotion) -> void:
	# Clamp the camera rotation (to prevent over rotating) and apply sensitivity
	camera_pitch = clamp(camera_pitch - event.relative.y * look_sensitivity_mouse, -80, 90)
	# Apply pitch to the camera pivot (or this camera if pivot is not assigned)
	camera_base.rotation_degrees.x = -camera_pitch
	# Get the relative mouse movement in the x direction
	var relative_x = event.relative.x
	# Define the new rotation in the y direction based on the relative x movement and sensitivity
	var new_rotation_y = -relative_x * look_sensitivity_mouse
	# Rotate the player along the y-axis by the new rotation value
	player.rotate(player.basis.y, deg_to_rad(new_rotation_y))
	# If the player is strafing...
	if player.is_strafing:
		# Rotate the camera around the player
		camera_base.rotate_y(deg_to_rad(new_rotation_y))
