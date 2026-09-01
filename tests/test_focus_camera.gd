extends GutTest

const PLAYER_SCENE = preload("res://addons/3d_player_controller/scenes/player.tscn")
const CONTROLS_SCENE = preload("res://addons/3d_player_controller/scenes/controls.tscn")


func test_focus_levels_vertical_camera_pitch_without_target() -> void:
	var controls = CONTROLS_SCENE.instantiate()
	add_child_autofree(controls)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	var camera: Camera = player.camera as Camera
	assert_not_null(camera, "Camera should exist on Player")

	# Set camera mount pitch to look straight up (e.g. 1.0 rad)
	camera.camera_mount.rotation.x = 1.0
	var initial_pitch: float = camera.camera_mount.rotation.x

	Input.action_press("focus")
	assert_true(player.is_focusing, "player.is_focusing should be true")

	camera._process(0.2)

	# The pitch should have moved towards -15 degrees (-0.2618 rad)
	var expected_pitch: float = deg_to_rad(-15.0)
	assert_true(abs(camera.camera_mount.rotation.x - expected_pitch) < abs(initial_pitch - expected_pitch),
		"Camera pitch should move toward default -15 deg when focusing without target")

	Input.action_release("focus")


func test_focus_tracks_elevated_target_pitch_and_yaw() -> void:
	var controls = CONTROLS_SCENE.instantiate()
	add_child_autofree(controls)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	var camera: Camera = player.camera as Camera

	var target = Node3D.new()
	add_child_autofree(target)
	target.global_position = player.global_position + Vector3(0, 10, -10)

	var focus_node: Focus = player.get_node("Focus") as Focus
	focus_node.current_focus_target = target

	Input.action_press("focus")
	assert_true(player.is_focusing, "player.is_focusing should be true")
	assert_eq(player.current_focus_target, target, "current_focus_target should be set")

	camera.camera_mount.rotation.x = 0.0
	camera._process(0.2)

	assert_gt(camera.camera_mount.rotation.x, 0.0, "Camera should pitch upward toward elevated target")

	Input.action_release("focus")


func test_focus_uses_marker3d_focus_target() -> void:
	var target_body = Node3D.new()
	add_child_autofree(target_body)
	target_body.position = Vector3(0, 0, 10)

	var marker = Marker3D.new()
	marker.name = "Marker3D_FocusTarget"
	marker.position = Vector3(0, 1.75, 0)
	target_body.add_child(marker)

	var resolved_node = Focus.get_focus_target_node(target_body)
	assert_eq(resolved_node, marker, "get_focus_target_node should find Marker3D_FocusTarget")

	var resolved_pos = Focus.get_focus_target_position(target_body)
	assert_almost_eq(resolved_pos.y, 1.75, 0.01, "get_focus_target_position should point to marker elevation")


func test_focus_aim_offset_shrinks_with_distance() -> void:
	var controls = CONTROLS_SCENE.instantiate()
	add_child_autofree(controls)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	var camera: Camera = player.camera as Camera

	# Equip bow equipment so is_shooting can be active
	var eq = Equipment.new()
	eq.equipment_type = Equipment.EquipmentType.BOW
	add_child_autofree(eq)
	player.inventory.add_equipment(eq)
	player.inventory.can_player_shoot = true

	# Test 1: Target close (2m away)
	var near_target = Node3D.new()
	add_child_autofree(near_target)
	near_target.global_position = camera.camera_mount.global_position + Vector3(0, 0, -2.0)

	var focus_node: Focus = player.get_node("Focus") as Focus
	focus_node.current_focus_target = near_target

	var near_max_angle: float = camera.get_max_focus_aim_angle()
	var expected_near_angle: float = atan2(0.5, 2.0)
	assert_almost_eq(near_max_angle, expected_near_angle, 0.01, "Near target aim angle should be atan2(0.5, 2.0)")

	# Test 2: Target far (10m away)
	var far_target = Node3D.new()
	add_child_autofree(far_target)
	far_target.global_position = camera.camera_mount.global_position + Vector3(0, 0, -10.0)
	focus_node.current_focus_target = far_target

	var far_max_angle: float = camera.get_max_focus_aim_angle()
	var expected_far_angle: float = atan2(0.5, 10.0)
	assert_almost_eq(far_max_angle, expected_far_angle, 0.01, "Far target aim angle should be atan2(0.5, 10.0)")
	assert_lt(far_max_angle, near_max_angle, "Aim angle window must shrink the further away the target is")

	# Test input clamping at far distance
	Input.action_press("focus")
	Input.action_press("shoot")
	var motion_event = InputEventMouseMotion.new()
	motion_event.relative = Vector2(-500, -500)
	camera._input(motion_event)
	assert_almost_eq(camera.focus_aim_offset.length(), far_max_angle, 0.001, "Aim offset should clamp to distance-scaled maximum")

	Input.action_release("shoot")
	camera._process(0.2)
	assert_lt(camera.focus_aim_offset.length(), far_max_angle, "Aim offset should decay when not shooting")

	Input.action_release("focus")


func test_aim_fov_and_shoulder_offset_framing() -> void:
	var controls = CONTROLS_SCENE.instantiate()
	add_child_autofree(controls)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	var camera: Camera = player.camera as Camera

	var eq = Equipment.new()
	eq.equipment_type = Equipment.EquipmentType.BOW
	add_child_autofree(eq)
	player.inventory.add_equipment(eq)
	player.inventory.can_player_shoot = true

	var base_fov: float = camera.fov
	var base_h_offset: float = camera.h_offset

	# Press shoot to aim
	Input.action_press("shoot")
	assert_true(player.is_shooting, "Player should be shooting/aiming")

	# Process frames to let FOV and shoulder offset interpolate
	for i in range(10):
		camera._process(0.1)

	assert_lt(camera.fov, base_fov, "FOV should narrow during aim (zoom in)")
	assert_gt(camera.h_offset, base_h_offset, "Shoulder offset should shift right for clear line of sight")

	# Release shoot to exit aim
	Input.action_release("shoot")
	for i in range(10):
		camera._process(0.1)

	assert_almost_eq(camera.fov, camera.default_fov, 0.5, "FOV should return to default after aiming")
	assert_almost_eq(camera.h_offset, camera.default_h_offset, 0.05, "Shoulder offset should return to center after aiming")


func test_firearm_aiming_does_not_lock_on_and_updates_contextual_label() -> void:
	var controls = CONTROLS_SCENE.instantiate()
	add_child_autofree(controls)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	var camera: Camera = player.camera as Camera

	# 1. Equip a Rifle (Firearm)
	var rifle = Equipment.new()
	rifle.equipment_type = Equipment.EquipmentType.RIFLE
	rifle.can_shoot = true
	add_child_autofree(rifle)
	player.inventory.add_equipment(rifle)

	assert_true(player.has_firearm_equipped, "player.has_firearm_equipped should be true")
	assert_false(player.has_bow_equipped, "player.has_bow_equipped should be false")
	assert_eq(player.controls.joypad_axis_4_plus_label.text, "Aim", "Contextual control label should be 'Aim' for firearms")

	# Test: Pressing shoot alone on a firearm must NOT zoom in
	var base_fov = camera.fov
	Input.action_press("shoot")
	assert_true(player.is_shooting, "player.is_shooting should be true")
	for i in range(5):
		camera._process(0.1)
	assert_almost_eq(camera.fov, base_fov, 0.1, "Shooting with firearm alone should NOT zoom in")
	Input.action_release("shoot")

	# Create a nearby target body in group "Target"
	var target = CharacterBody3D.new()
	target.name = "GuyTarget"
	target.add_to_group("Target")
	add_child_autofree(target)
	target.global_position = player.global_position + Vector3(0, 0, -3.0)

	var focus_node: Focus = player.get_node("Focus") as Focus

	# Press "focus" action (Aim for firearms)
	Input.action_press("focus")
	assert_true(player.is_focusing, "player.is_focusing should be true")
	assert_true(player.is_aiming_firearm, "player.is_aiming_firearm should be true")

	# Aiming firearm should zoom in
	for i in range(10):
		camera._process(0.1)
	assert_lt(camera.fov, base_fov, "Aiming with firearm should zoom in")

	# When aiming and moving, player should face camera and pass motion to blend space
	player.player_input.motion = Vector2(1, 0)
	for i in range(5):
		player._physics_process(0.05)
	
	var blend_pos: Vector2 = player.animation_tree.get(Player.RIFLE_LOCOMOTION_BLEND_POSITION_PATH)
	assert_gt(blend_pos.x, 0.0, "Rifle locomotion blend position X should reflect right strafe input")

	focus_node._physics_process(0.1)
	assert_null(focus_node.current_focus_target, "Firearms must not lock on to targets")

	# Rotate camera freely with mouse while aiming firearm
	var initial_yaw = camera.camera_mount.rotation.y
	var motion_event = InputEventMouseMotion.new()
	motion_event.relative = Vector2(100, 0)
	camera._input(motion_event)
	assert_ne(camera.camera_mount.rotation.y, initial_yaw, "Camera should rotate freely with mouse during firearm aim")

	Input.action_release("focus")
	player.player_input.motion = Vector2.ZERO

	# 2. Unequip rifle and equip Bow
	player.inventory.remove_equipment(rifle)
	var bow = Equipment.new()
	bow.equipment_type = Equipment.EquipmentType.BOW
	add_child_autofree(bow)
	player.inventory.add_equipment(bow)

	assert_false(player.has_firearm_equipped, "player.has_firearm_equipped should be false after unequip")
	assert_true(player.has_bow_equipped, "player.has_bow_equipped should be true")
	assert_eq(player.controls.joypad_axis_4_plus_label.text, "Focus", "Contextual control label should be 'Focus' for Bow")
