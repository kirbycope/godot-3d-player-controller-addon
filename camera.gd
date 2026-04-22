extends Camera3D

enum Perspective {
	FIRST_PERSON,
	THIRD_PERSON,
}

@export var camera_base: Node3D ## Reference to the $CameraBase
@export var look_sensitivity_mouse := 0.2 ## Mouse look sensitivity
@export var perspective: Perspective = Perspective.THIRD_PERSON ## The current camera perspective
@export var player: Player ## Reference to the [Player] node
@export var player_model: Node3D ## Reference to the player's model (`Pivot/RootMotion/PlayerModel`)

var camera_pitch := 0.0 ## Camera pitch (up/down) rotation in degrees


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Toggle mouse capture
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() in [Input.MOUSE_MODE_CAPTURED, Input.MOUSE_MODE_HIDDEN]:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Check for mouse motion
	if event is InputEventMouseMotion:
		# Check if the mouse is captured or hidden -> Rotate camera
		if Input.get_mouse_mode() in [Input.MOUSE_MODE_CAPTURED, Input.MOUSE_MODE_HIDDEN]:
			camera_rotate_by_mouse(event)


## Rotate camera using the mouse motion.
func camera_rotate_by_mouse(event: InputEvent) -> void:
	camera_pitch = clamp(camera_pitch - event.relative.y * look_sensitivity_mouse, -80, 90)
	var relative_x = event.relative.x
	var new_rotation_y = -relative_x * look_sensitivity_mouse

	if Input.is_action_pressed("turn_camera"):
		# Strafe mode: orbit camera around player
		camera_base.rotation_degrees.y += new_rotation_y
	else:
		# Free-move mode: rotate player (camera follows)
		player.rotate(player.basis.y, deg_to_rad(new_rotation_y))

	# Rotate the camera to match the mouse movement on the X axis (up/down)
	camera_base.rotation_degrees.x = -camera_pitch
