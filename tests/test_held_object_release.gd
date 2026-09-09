extends GutTest
## A held object never sits in the ground or inside the Player however the camera pitches, and a released body
## passes through the Player for a moment so it leaves cleanly instead of being shoved out.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const CONTROLS_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player_controls.tscn")

var player: Player
var body: RigidBody3D


func before_each() -> void:
	add_child_autofree(CONTROLS_SCENE.instantiate())
	var root := Node3D.new()
	add_child_autofree(root)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(40.0, 1.0, 40.0)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	body = RigidBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	shape.shape.radius = 0.4
	body.add_child(shape)
	root.add_child(body)
	body.global_position = Vector3(0.0, 1.0, -2.0)
	await wait_physics_frames(5)


func test_looking_down_keeps_the_held_object_above_the_ground_and_out_of_the_player() -> void:
	player.held_object._pickup_rigidbody(body)
	player.camera_mount.rotation.x = -1.4 # Almost straight down
	await wait_physics_frames(3)
	var offset: Vector3 = body.global_position - player.global_position
	assert_gt(body.global_position.y, 0.6, "Above the floor, not in it")
	assert_gt(Vector2(offset.x, offset.z).length(), 1.2, "Held out in front, not inside the Player")
	player.held_object._held_distance = player.held_object.held_min_distance
	await wait_physics_frames(3)
	offset = body.global_position - player.global_position
	assert_gt(Vector2(offset.x, offset.z).length(), 0.45, "Pulled in close it still clears the capsule")
	player.camera_mount.rotation.x = 1.2 # Almost straight up
	await wait_physics_frames(3)
	var up_pitch: float = asin(clampf((body.global_position - player.camera_mount.global_position).normalized().y, -1.0, 1.0))
	assert_lte(up_pitch, player.camera.held_pitch_max + 0.05, "Looking up the arm stops at held_pitch_max")
	player.camera_mount.rotation.x = -1.4
	await wait_physics_frames(3)
	var down_pitch: float = asin(clampf((body.global_position - player.camera_mount.global_position).normalized().y, -1.0, 1.0))
	assert_gte(down_pitch, player.camera.held_pitch_min - 0.05, "Looking down the arm stops at held_pitch_min")
	player.held_object.drop_held_rigidbody()


func test_a_released_body_passes_through_the_player_for_a_moment() -> void:
	player.held_object._pickup_rigidbody(body)
	await wait_physics_frames(3)
	player.held_object.execute_instant_throw(Vector3.FORWARD, 1.0)
	assert_false(player.held_object.is_holding_object())
	assert_true(player.get_collision_exceptions().has(body), "Right after the throw the body still ignores the Player")
	await wait_seconds(HeldObject.RELEASE_GRACE + 0.15)
	assert_false(player.get_collision_exceptions().has(body), "A moment later they collide again")
	assert_false(body.get_collision_exceptions().has(player))


func test_picking_the_body_back_up_inside_the_grace_keeps_the_exception() -> void:
	player.held_object._pickup_rigidbody(body)
	await wait_physics_frames(2)
	player.held_object.drop_held_rigidbody()
	player.held_object._pickup_rigidbody(body)
	await wait_seconds(HeldObject.RELEASE_GRACE + 0.15)
	assert_true(player.held_object.is_holding_rigidbody())
	assert_true(player.get_collision_exceptions().has(body), "The grace ending must not strip the exception from a body held again")


func test_the_arm_aims_at_an_object_moved_beside_the_player_and_a_wall_there_stops_it() -> void:
	player.held_object._pickup_rigidbody(body)
	player.camera_mount.rotation = Vector3.ZERO
	await wait_physics_frames(3)
	var arm: SpringArm3D = player.item_spring_arm
	var forward: Vector3 = (-player.camera_mount.global_basis.z).slide(Vector3.UP).normalized()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	var offset: Vector3 = body.global_position - arm.global_position
	assert_lt(absf(offset.dot(right)), 0.15, "Held straight ahead to start")
	player.held_object._held_offset = Vector2(1.0, 0.0) # the look stick pushed it a metre to the right
	await wait_physics_frames(3)
	offset = body.global_position - arm.global_position
	assert_almost_eq(offset.dot(right), 1.0, 0.15, "The object sits a metre to the right")
	assert_almost_eq(arm.spring_length, Vector2(player.held_object._held_distance, 1.0).length(), 0.05, "and the arm reaches for it on the diagonal, so its cast covers where it is")
	assert_lt(absf(body.position.x) + absf(body.position.y), 0.01, "not hung off the arm's axis")
	# A wall half a metre to the right of the aim line
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(0.2, 4.0, 8.0)
	wall.add_child(shape)
	player.get_parent().add_child(wall)
	wall.global_position = arm.global_position + right * 0.6 + forward * 2.0
	wall.global_basis = Basis.looking_at(forward, Vector3.UP)
	await wait_physics_frames(3)
	offset = body.global_position - arm.global_position
	assert_lt(arm.get_hit_length(), arm.spring_length - 0.5, "The wall stops the arm short")
	assert_lt(offset.dot(right), 0.8, "so the object is pulled back before the wall instead of hung beyond it")
	player.held_object.drop_held_rigidbody()
	wall.free()
