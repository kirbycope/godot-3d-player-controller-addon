extends GutTest

const PLAYER_SCENE = preload("res://addons/3d_player_controller/scenes/player.tscn")
const CONTROLS_SCENE = preload("res://addons/3d_player_controller/scenes/controls.tscn")


func test_held_object_45_degree_rotation_snapping() -> void:
	var controls = CONTROLS_SCENE.instantiate()
	add_child_autofree(controls)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	var held_object: HeldObject = player.held_object as HeldObject
	assert_not_null(held_object, "HeldObject node should exist")

	var rb = RigidBody3D.new()
	var col = CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	rb.add_child(col)
	add_child_autofree(rb)
	rb.global_position = player.global_position + Vector3(0, 0, -2)

	held_object._pickup_rigidbody(rb)
	assert_true(held_object.is_holding_rigidbody(), "Should be holding rigidbody")

	# Enter rotation mode
	held_object._is_held_rotation_mode = true
	held_object.use_discrete_rotation_snap = true
	held_object.rotation_snap_angle = 45.0

	var initial_rot = rb.rotation_degrees

	# Tap next_weapon (D-pad Right) -> should rotate by 45 degrees
	var event = InputEventAction.new()
	event.action = "next_weapon"
	event.pressed = true
	held_object._input(event)

	var delta_y = abs(rb.rotation_degrees.y - initial_rot.y)
	assert_almost_eq(delta_y, 45.0, 1.0, "D-pad press in rotation mode should snap rotation by 45 degrees")

	held_object.drop_held_rigidbody()
