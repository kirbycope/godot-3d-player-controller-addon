extends GutTest

## Purpose: a rigid body the Player stands on is a prop, not a lift. Leaving one must not hand the Player the speed
## of its surface, the way leaving a moving platform does; a snowball rolling away from the Player's legs, its back
## coming up as it turned, used to launch the Player a metre and a half into the air.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")

var root: Node3D
var player: Player


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)


func _floor(body: PhysicsBody3D) -> PhysicsBody3D:
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(20.0, 1.0, 20.0)
	body.add_child(shape)
	body.position.y = -0.5
	root.add_child(body)
	return body


func _stand_on(body: PhysicsBody3D) -> void:
	_floor(body)
	player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await wait_physics_frames(10)


func test_standing_on_a_rigid_body_takes_none_of_its_speed_on_leaving() -> void:
	var crate := RigidBody3D.new()
	crate.freeze = true # Held still so the Player can settle on it; it is still a RigidBody3D.
	await _stand_on(crate)
	assert_true(player.is_on_floor(), "The Player stands on it")
	assert_true(player.is_standing_on_rigid_body(), "and knows it is a rigid body")
	player.update_movement_and_rotation(1.0 / 60.0)
	assert_eq(player.platform_on_leave, CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING, "so stepping off it adds nothing")


func test_standing_on_the_ground_keeps_what_platforms_give() -> void:
	await _stand_on(StaticBody3D.new())
	assert_false(player.is_standing_on_rigid_body())
	player.update_movement_and_rotation(1.0 / 60.0)
	assert_eq(player.platform_on_leave, CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY, "A moving platform still carries the Player off it")
