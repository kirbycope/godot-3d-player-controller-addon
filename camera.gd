extends Camera3D

@export var joypad_sensitivity: float = 100.0
@export var mouse_sensitivity: float = 0.1

@onready var camera_spring_arm: SpringArm3D = get_parent()
@onready var player: Player = camera_spring_arm.get_parent() as Player


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Rotate the [Camera3D]'s [SpringArm3D] using the mouse motion input event
	if event is InputEventMouseMotion \
	and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
	and not player.is_strafing:
		rotate_camera_using_mouse_motion(event)


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Rotate the [Camera3D]'s [SpringArm3D] using the joypad motion input event
	if Input.get_vector("look_left", "look_right", "look_up", "look_down") != Vector2.ZERO:
		rotate_camera_using_joypad_motion(delta)

	# Slerp camera to face the player's direction when strafing (but not when bow is active)
	#if player.is_strafing and not (player.is_drawing_arrow or player.is_aiming_bow or player.is_shooting_bow):
		#camera_spring_arm.rotation.y = lerp_angle(camera_spring_arm.rotation.y, player.pivot.rotation.y + PI, delta * 8.0)


## Rotates the [Camera3D]'s [SpringArm3D] using the input from a joypad motion event, while clamping the vertical rotation to prevent flipping.
func rotate_camera_using_joypad_motion(delta: float) -> void:
	# Get the input from the joypad motion event
	var joypad_motion_input: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	# Rotate the [Camera3D]'s [SpringArm3D] horizontally using the joypad motion input's x value
	if joypad_motion_input.x != 0:
		camera_spring_arm.rotate_y(deg_to_rad(-joypad_motion_input.x * joypad_sensitivity * delta))
	# Rotate the [Camera3D]'s [SpringArm3D] vertically using the joypad motion input's y value
	if joypad_motion_input.y != 0:
		var new_rotation_x: float = camera_spring_arm.rotation_degrees.x - joypad_motion_input.y * joypad_sensitivity * delta
		# Clamp the rotation to prevent flipping
		new_rotation_x = clamp(new_rotation_x, -89, 89)
		# Apply the new rotation to the [Camera3D]'s [SpringArm3D]
		camera_spring_arm.rotation_degrees.x = new_rotation_x


## Rotates the [Camera3D]'s [SpringArm3D] using the input from a mouse motion event, while clamping the vertical rotation to prevent flipping.
func rotate_camera_using_mouse_motion(event: InputEventMouseMotion) -> void:
	# Get the input from the mouse motion event
	var mouse_motion_input: Vector2 = event.relative
	# Rotate the [Camera3D]'s [SpringArm3D] horizontally using the mouse motion input's x value
	camera_spring_arm.rotate_y(deg_to_rad(-mouse_motion_input.x * mouse_sensitivity))
	# Rotate the [Camera3D]'s [SpringArm3D] vertically using the mouse motion input's y value
	var new_rotation_x: float = camera_spring_arm.rotation_degrees.x - mouse_motion_input.y * mouse_sensitivity
	# Clamp the rotation to prevent flipping
	new_rotation_x = clamp(new_rotation_x, -89, 89)
	# Apply the new rotation to the [Camera3D]'s [SpringArm3D]
	camera_spring_arm.rotation_degrees.x = new_rotation_x
