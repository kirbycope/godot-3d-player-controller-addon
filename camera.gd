extends Camera3D
class_name Camera

enum Perspective {
	FIRST_PERSON, ## Rendered from the viewpoint of the player character
	THIRD_PERSON, ## Rendered from a fixed distance behind and slightly above the player character.
}

const SKATEBOARDING_CAMERA_FOLLOW_DELAY: float = 2.0

@export var camera_spring_arm: SpringArm3D
@export var first_person_offset: Vector3 = Vector3(0.0, 0.0, -0.3) ## The offset of the camera from the player's head when in first-person perspective.
@export var joypad_sensitivity: float = 100.0
@export var mouse_sensitivity: float = 0.1
@export var perspective: Perspective = Perspective.THIRD_PERSON ## What perspective should the Camera use?
@export var player: Player

var first_person_bone_attachment: BoneAttachment3D
var looking_at: Node3D = null
var skateboarding_camera_follow_delay_remaining: float = 0.0

@onready var camera_initial_transform: Transform3D = transform
@onready var camera_ray_cast: RayCast3D = $CameraRayCast
@onready var camera_ray_cast_initial_position: Vector3 = camera_ray_cast.position


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Ensure the [RayCast3D] doesn't collide with the player
	camera_ray_cast.add_exception(player)

	# Ensure the Camera's [SpringArm3D] doesn't collide with the player
	camera_spring_arm.add_excluded_object(player.get_rid())

	# Match the [RayCast3D] offset to the starting perspective (scene offset is for third-person)
	if perspective == Perspective.FIRST_PERSON:
		camera_ray_cast.position = Vector3.ZERO


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Check if the player is interacting with an equipment item
	if looking_at and event.is_action_pressed("action") and looking_at.has_method("equip"):
		looking_at.equip(player)
		looking_at = null

	# Perspective { Microsoft: ⧉, Nintendo: ⊝, Sony: ⦀, Keyboard: [F5] }
	if event.is_action_pressed("perspective"):
		if perspective == Perspective.FIRST_PERSON:
			perspective = Perspective.THIRD_PERSON
			transform = camera_initial_transform
		else:
			perspective = Perspective.FIRST_PERSON
		_update_raycast()

	# Rotate the [Camera3D]'s [SpringArm3D] using the mouse motion input event
	if event is InputEventMouseMotion \
	and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED\
	and not player.is_focusing:
		rotate_camera_using_mouse_motion(event)
		if player.is_skateboarding and event.relative.length_squared() > 0.0:
			defer_skateboarding_camera_follow()

	# Only continue if the perspective is third-person
	if perspective == Perspective.THIRD_PERSON:
		# If Mouse scroll wheel up
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Shorten the camera spring arm, min 1.0
			camera_spring_arm.spring_length = max(camera_spring_arm.spring_length - 0.1, 1.0)
			# TODO: If the player tries to zoom in further, switch to first-person perspective instead?
			_update_raycast()

		# If Mouse scroll wheel down
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Lengthen the camera spring arm, max 6.0
			camera_spring_arm.spring_length = min(camera_spring_arm.spring_length + 0.1, 6.0)
			_update_raycast()


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	if perspective == Perspective.FIRST_PERSON:
		move_camera_to_player_head()

	# Rotate the [Camera3D]'s [SpringArm3D] using the joypad motion input event
	var joypad_motion_input: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if joypad_motion_input != Vector2.ZERO:
		rotate_camera_using_joypad_motion(delta)
		if player.is_skateboarding:
			defer_skateboarding_camera_follow()

	if skateboarding_camera_follow_delay_remaining > 0.0:
		skateboarding_camera_follow_delay_remaining = max(
				skateboarding_camera_follow_delay_remaining - delta,
				0.0
		)

	# Lerp camera to face the player's direction when focusing or skateboarding.
	if (player.is_focusing \
	or player.is_skateboarding and skateboarding_camera_follow_delay_remaining <= 0.0) \
	and perspective != Perspective.FIRST_PERSON:
		camera_spring_arm.rotation.y = lerp_angle(camera_spring_arm.rotation.y, player.player_model.rotation.y + PI, delta * 8.0)


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Keep the [Camera3D] (and its child [RayCast3D]) at the player's head before the raycast is
	# evaluated, otherwise the parent [SpringArm3D] leaves it at the spring position this physics frame
	if perspective == Perspective.FIRST_PERSON:
		move_camera_to_player_head()

	# Check if the "CameraRayCast" is colliding with an object that has a "display_menu" method, and if so, call that method
	if camera_ray_cast.is_colliding():
		var collider = camera_ray_cast.get_collider()
		if collider:
			var target = null
			var current_node = collider
			while current_node:
				if current_node.has_method("display_menu"):
					target = current_node
					break
				current_node = current_node.get_parent()
			
			if target:
				if looking_at and looking_at != target and looking_at.has_method("hide_menu"):
					looking_at.hide_menu()
				target.display_menu(player)
				looking_at = target
			else:
				if looking_at and looking_at.has_method("hide_menu"):
					looking_at.hide_menu()
				looking_at = null
	else:
		if looking_at and looking_at.has_method("hide_menu"):
			looking_at.hide_menu()
		looking_at = null


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


func defer_skateboarding_camera_follow() -> void:
	skateboarding_camera_follow_delay_remaining = SKATEBOARDING_CAMERA_FOLLOW_DELAY


## Update the camera to follow the character head's position (while in "first-person").
func move_camera_to_player_head() -> void:
	if first_person_bone_attachment == null:
		first_person_bone_attachment = player.skeleton.get_node("FirstPersonCameraBoneAttachment") as BoneAttachment3D

	global_position = first_person_bone_attachment.global_position
	global_rotation = camera_spring_arm.global_rotation
	global_position += global_transform.basis.z * first_person_offset.z
	global_position += global_transform.basis.y * first_person_offset.y
	global_position += global_transform.basis.x * first_person_offset.x


## Updates the [RayCast3D] position and target_position based on current perspective/depth.
func _update_raycast() -> void:
	if not is_instance_valid(camera_ray_cast):
		return

	if perspective == Perspective.FIRST_PERSON:
		camera_ray_cast.position = Vector3.ZERO
		camera_ray_cast.target_position = Vector3(0, 0, -3.0)
	else:
		camera_ray_cast.position = Vector3(0, 0, -1.0)
		var length := 2.0
		if is_instance_valid(camera_spring_arm):
			length = camera_spring_arm.spring_length
		camera_ray_cast.target_position = Vector3(0, 0, -(length + 1.0))
