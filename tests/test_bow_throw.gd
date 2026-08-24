extends GutTest

## Purpose: To test that throwing a held object while having a bow equipped does not trigger bow draw sound/state.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")

class MockHeldCharacter extends CharacterBody3D:
	var player: Player
	var is_held: bool = false
	
	func pick_up() -> void:
		if not player or not player.item_spring_arm:
			return
		is_held = true
		if get_parent():
			get_parent().remove_child(self)
		player.item_spring_arm.add_child(self)
		position = Vector3.ZERO

var root: Node3D
var player: Player

func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	player = PLAYER_SCENE.instantiate() as Player
	root.add_child(player)
	await wait_physics_frames(2)

func after_each() -> void:
	Input.action_release("shoot")
	if is_instance_valid(root):
		root.free()
		root = null

func test_holding_rigidbody_with_bow_equipped_blocks_bow_draw():
	# Create and equip a mock bow
	var bow = Node3D.new()
	bow.set_script(load("res://addons/3d_player_controller/scripts/bow.gd"))
	bow.equipment_type = Equipment.EquipmentType.BOW
	var draw_sound = AudioStreamPlayer3D.new()
	draw_sound.name = "BowDrawArrow"
	bow.add_child(draw_sound)
	root.add_child(bow)
	
	# Equip the bow in inventory
	player.inventory.add_equipment(bow)
	player.inventory.can_player_shoot = true
	assert_true(player.equipped_bow, "Bow should be equipped.")

	# Pick up a RigidBody3D
	var body = RigidBody3D.new()
	root.add_child(body)
	player.held_object._pickup_rigidbody(body)
	assert_true(player.held_object.is_holding_object(), "Player should be holding an object.")
	assert_false(player.is_shooting, "is_shooting should be false while holding object.")
	assert_false(player.is_drawing_arrow, "is_drawing_arrow should be false while holding object.")

	# Start charging throw
	player.start_charging_throw()
	assert_true(player.held_object.is_charging_throw, "Throw should be charging.")
	assert_false(player.is_shooting, "is_shooting should remain false while charging throw.")
	assert_false(player.is_drawing_arrow, "is_drawing_arrow should remain false while charging throw.")

	# Execute throw
	player.held_object.execute_throw()
	assert_false(player.is_drawing_arrow, "is_drawing_arrow should not be true on throw.")
	assert_false(draw_sound.playing, "Bow draw sound should not play on throw.")

func test_holding_little_buddy_with_bow_equipped_blocks_bow_draw():
	# Create and equip a mock bow
	var bow = Node3D.new()
	bow.set_script(load("res://addons/3d_player_controller/scripts/bow.gd"))
	bow.equipment_type = Equipment.EquipmentType.BOW
	var draw_sound = AudioStreamPlayer3D.new()
	draw_sound.name = "BowDrawArrow"
	bow.add_child(draw_sound)
	root.add_child(bow)
	
	player.inventory.add_equipment(bow)
	player.inventory.can_player_shoot = true
	assert_true(player.equipped_bow, "Bow should be equipped.")

	# Pick up Mock Held Character
	var buddy = MockHeldCharacter.new()
	root.add_child(buddy)
	buddy.player = player
	buddy.pick_up()
	assert_true(player.held_object.is_holding_object(), "is_holding_object should be true when Little Buddy is held.")
	assert_false(player.is_shooting, "is_shooting should be false while holding Little Buddy.")
	assert_false(player.is_drawing_arrow, "is_drawing_arrow should be false while holding Little Buddy.")

	# Start charging throw
	player.start_charging_throw()
	assert_false(player.is_shooting, "is_shooting should remain false while charging throw.")
	assert_false(player.is_drawing_arrow, "is_drawing_arrow should remain false while charging throw.")

	# Execute instant throw
	player.held_object.execute_instant_throw(Vector3.FORWARD, 1.0)
	assert_false(player.is_drawing_arrow, "is_drawing_arrow should not be true after throw.")
	assert_false(draw_sound.playing, "Bow draw sound should not play on throw.")

func test_shooting_bow_works_normally_when_empty_handed():
	var bow = Node3D.new()
	bow.set_script(load("res://addons/3d_player_controller/scripts/bow.gd"))
	bow.equipment_type = Equipment.EquipmentType.BOW
	root.add_child(bow)

	player.inventory.add_equipment(bow)
	player.inventory.can_player_shoot = true
	assert_true(player.equipped_bow, "Bow should be equipped.")
	assert_false(player.held_object.is_holding_object(), "Player is not holding an object.")

	# Press shoot action
	Input.action_press("shoot")
	assert_true(player.is_shooting, "is_shooting should be true when pressing shoot with bow equipped and empty hands.")
	Input.action_release("shoot")
	assert_false(player.is_shooting, "is_shooting should be false when shoot action is released.")
