extends GutTest

## Purpose: To test bow firing, and that throwing a held object while a bow is equipped does not trigger the bow.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const BOW_SCRIPT: Script = preload("res://addons/3d_player_controller/scripts/bow.gd")
const ARROW_SCRIPT: Script = preload("res://addons/3d_player_controller/scripts/arrow.gd")

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


## A bow with a draw sound; `with_player` wires it to the player's locomotion signal like equip() does.
func _make_bow(with_player: bool) -> Bow:
	var bow = Node3D.new()
	bow.set_script(BOW_SCRIPT)
	bow.equipment_type = Equipment.EquipmentType.BOW
	var draw_sound = AudioStreamPlayer3D.new()
	draw_sound.name = "BowDrawArrow"
	bow.add_child(draw_sound)
	if with_player:
		bow.player = player
	root.add_child(bow)
	player.inventory.add_equipment(bow)
	player.inventory.can_player_shoot = true
	return bow


func test_holding_rigidbody_with_bow_equipped_blocks_bow_draw():
	var bow = _make_bow(true)
	var draw_sound = bow.get_node("BowDrawArrow")
	assert_true(player.equipped_bow, "Bow should be equipped.")

	var body = RigidBody3D.new()
	root.add_child(body)
	player.held_object._pickup_rigidbody(body)
	assert_true(player.held_object.is_holding_object(), "Player should be holding an object.")
	assert_false(player.is_shooting, "is_shooting should be false while holding object.")
	assert_false(player.is_drawing_arrow, "is_drawing_arrow should be false while holding object.")
	assert_true(player.look_at_modifier.active, "Picking up should point the look-at modifier at the body.")

	player.start_charging_throw()
	assert_true(player.held_object.is_charging_throw, "Throw should be charging.")
	assert_false(player.is_shooting, "is_shooting should remain false while charging throw.")

	# A draw node change while holding must not trigger the bow
	bow._on_locomotion_node_changed("Bow/BowDrawArrow")
	assert_false(draw_sound.playing, "Bow draw sound should not play while holding an object.")

	player.held_object.execute_throw()
	assert_false(player.is_drawing_arrow, "is_drawing_arrow should not be true on throw.")
	assert_false(draw_sound.playing, "Bow draw sound should not play on throw.")
	assert_false(player.look_at_modifier.active, "Throwing should clear the look-at modifier.")


func test_holding_little_buddy_with_bow_equipped_blocks_bow_draw():
	var bow = _make_bow(false)
	var draw_sound = bow.get_node("BowDrawArrow")

	var buddy = MockHeldCharacter.new()
	root.add_child(buddy)
	buddy.player = player
	buddy.pick_up()
	assert_true(player.held_object.is_holding_object(), "is_holding_object should be true when Little Buddy is held.")
	assert_false(player.is_shooting, "is_shooting should be false while holding Little Buddy.")

	player.start_charging_throw()
	assert_false(player.is_drawing_arrow, "is_drawing_arrow should remain false while charging throw.")

	player.held_object.execute_instant_throw(Vector3.FORWARD, 1.0)
	assert_false(player.is_drawing_arrow, "is_drawing_arrow should not be true after throw.")
	assert_false(draw_sound.playing, "Bow draw sound should not play on throw.")


func test_shooting_bow_works_normally_when_empty_handed():
	_make_bow(false)
	assert_false(player.held_object.is_holding_object(), "Player is not holding an object.")
	Input.action_press("shoot")
	assert_true(player.is_shooting, "is_shooting should be true when pressing shoot with bow equipped and empty hands.")
	Input.action_release("shoot")
	assert_false(player.is_shooting, "is_shooting should be false when shoot action is released.")


func test_fire_node_spawns_one_arrow_along_the_projectile_ray():
	var bow = _make_bow(true)
	var template = RigidBody3D.new()
	template.name = "Arrow"
	template.set_script(ARROW_SCRIPT)
	bow.add_child(template)
	bow.arrow_node = template
	await wait_physics_frames(1)
	assert_true(template.freeze, "The template arrow stays frozen.")

	var arrows_before: int = root.get_children().filter(func(n): return n is Arrow).size()
	bow._on_locomotion_node_changed("Bow/BowFireArrow")
	var arrows: Array = root.get_children().filter(func(n): return n is Arrow)
	assert_eq(arrows.size(), arrows_before + 1, "Firing should spawn exactly one arrow.")

	var arrow: Arrow = arrows.back()
	assert_false(arrow.is_template, "The fired arrow is not a template.")
	assert_eq(arrow.shooter, player, "The fired arrow remembers its shooter.")
	assert_false(arrow.freeze, "The fired arrow is free to fly.")
	var ray_dir: Vector3 = -player.projectile_raycast.global_basis.z
	assert_almost_eq(arrow.linear_velocity.normalized().dot(ray_dir), 1.0, 0.05, "Arrow velocity should follow the projectile ray.")
	assert_almost_eq(arrow.linear_velocity.length(), bow.projectile_speed, 0.01, "Arrow speed should match the bow's projectile_speed.")
	arrow.free()


func test_arrow_frees_after_lifetime_and_forgets_shooter_exception():
	var arrow = RigidBody3D.new()
	arrow.set_script(ARROW_SCRIPT)
	arrow.is_template = false
	arrow.lifetime = 0.3
	arrow.shooter = player
	root.add_child(arrow)
	assert_true(player in arrow.get_collision_exceptions(), "A fresh arrow ignores its shooter.")
	await wait_seconds(0.2)
	assert_false(player in arrow.get_collision_exceptions(), "The shooter exception is dropped after a short delay.")
	await wait_seconds(0.2)
	assert_false(is_instance_valid(arrow), "The arrow frees itself once its lifetime elapses.")
