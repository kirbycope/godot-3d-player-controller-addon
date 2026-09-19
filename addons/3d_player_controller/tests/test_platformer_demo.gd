extends GutTest

## Purpose: The platformer demo is a playable slice: Jump sits on the bottom button, a second press in the air
## jumps again, coins are taken on touch and counted by the quest, a mushroom throws the Player up, a goon
## landed on from above is stomped and bounces the Player, the moving platform slides, and the flag ends the run.

const DEMO_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/demo/platformer/platformer_demo.tscn")
const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/platformer_skyline.tres")
const COIN: Item = preload("res://addons/3d_player_controller/resources/items/gold_coin.tres")

var demo: Node3D
var player: Player


func before_each() -> void:
	demo = DEMO_SCENE.instantiate()
	add_child_autofree(demo)
	await wait_physics_frames(3)
	player = demo.player


func after_each() -> void:
	_send(&"jump", false)


func _send(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func test_the_demo_sets_the_player_up_for_a_platformer() -> void:
	assert_eq(player.control_scheme, preload("res://addons/3d_player_controller/resources/control_schemes/platformer.tres"))
	assert_eq(player.controls.joypad_button_0_label.text, "Jump", "A is Jump")
	assert_true(player.enable_double_jump)
	assert_true(player.instant_jump, "The press itself leaves the ground")
	_send(&"jump", true)
	await wait_physics_frames(5)
	_send(&"jump", false)
	assert_gt(player.velocity.y, 3.0, "Up at once, not a third of a second later")
	assert_true(player.quest_log.is_active(QUEST), "The run starts on its own")
	assert_eq(demo.get_node("Islands/Coins").get_child_count(), 15)
	assert_true(demo.get_node("Islands/Platform") is MovingPlatform)
	assert_true(demo.get_node("Islands/Mushroom") is BouncePad)


func test_a_second_press_in_the_air_jumps_again_once() -> void:
	_send(&"jump", true)
	await wait_physics_frames(2)
	_send(&"jump", false)
	await wait_until(func() -> bool: return not player.is_on_floor(), 2.0)
	await wait_seconds(0.35)
	assert_eq(player.air_jumps_left, 1, "One in hand")
	var height: float = player.global_position.y
	_send(&"jump", true)
	await wait_physics_frames(2)
	_send(&"jump", false)
	await wait_seconds(0.4)
	assert_eq(player.air_jumps_left, 0, "Spent")
	assert_gt(player.global_position.y, height, "And it went up again")
	_send(&"jump", true)
	await wait_physics_frames(2)
	_send(&"jump", false)
	assert_eq(player.air_jumps_left, 0, "A third press gets nothing")


func test_a_coin_is_taken_on_touch_and_counted() -> void:
	var coin: ItemPickup = demo.get_node("Islands/Coins/Coin1")
	assert_true(coin.auto_take)
	player.warp_to(Transform3D(Basis(), coin.global_position))
	await wait_physics_frames(3)
	assert_eq(player.inventory.count_of(COIN), 1, "In the bag without a press")
	assert_eq(player.quest_log.get_count(QUEST, &"collect_coin"), 1)
	assert_false(is_instance_valid(coin) and coin.is_inside_tree(), "And gone from the island")


func test_the_mushroom_throws_the_player_up() -> void:
	var pad: BouncePad = demo.get_node("Islands/Mushroom")
	player.warp_to(Transform3D(Basis(), pad.global_position + Vector3(0.0, 1.5, 0.0)))
	await wait_physics_frames(3)
	assert_gt(player.velocity.y, 6.0, "Thrown up")
	assert_eq(player.current_state, NodeStateMachine.States.JUMPING)


func test_landing_on_a_goon_stomps_it_and_bounces() -> void:
	var goon: EnemyNpc = demo.get_node("Islands/Goons/Goon1")
	player.warp_to(Transform3D(Basis(), goon.global_position + Vector3(0.0, 2.6, 0.0)))
	await wait_until(func() -> bool: return goon.is_dead, 2.0)
	assert_true(goon.is_dead, "Stomped")
	assert_gt(player.velocity.y, 0.0, "And bounced off its head")


func test_the_platform_slides_and_the_flag_ends_the_run() -> void:
	var platform: MovingPlatform = demo.get_node("Islands/Platform")
	var start: Vector3 = platform.global_position
	await wait_seconds(0.8)
	assert_lt(platform.global_position.z, start.z - 0.5, "On its way")
	player.inventory.add_item(COIN, 15)
	player.quest_log.progress(&"collect_coin", 15)
	demo._on_goal_body_entered(player)
	assert_true(player.quest_log.is_complete(QUEST), "The flag with all the coins is the run")
