extends GutTest

## Purpose: The ARPG demo is a playable slice from above: the camera is locked to its angle, a click on the floor
## walks the Player there, Fireball is the active ability and hurts what it lands on, the halls' waves start at
## the first hall and count for the quest, a ghoul drops gold where it falls, and the Crypt Lord wakes on his
## sigil and ends the run.

const DEMO_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/demo/arpg/arpg_demo.tscn")
const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/arpg_crypt.tres")
const COIN: Item = preload("res://addons/3d_player_controller/resources/items/gold_coin.tres")
const FIREBALL: Ability = preload("res://addons/3d_player_controller/resources/abilities/fireball.tres")

var demo: Node3D
var player: Player


func before_each() -> void:
	demo = DEMO_SCENE.instantiate()
	add_child_autofree(demo)
	await wait_physics_frames(3)
	player = demo.player


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_the_view_is_locked_from_above_and_fireball_is_the_ability() -> void:
	var camera: Camera = player.camera
	assert_true(camera.locked_view)
	await wait_process_frames(2)
	assert_almost_eq(player.camera_mount.rotation_degrees.x, camera.locked_pitch_degrees, 0.5)
	assert_eq(player.abilities.active_ability, FIREBALL)
	assert_eq(player.controls.joypad_button_9_label.text, "Fireball", "On the shoulder button")
	assert_true(player.quest_log.is_active(QUEST))


func test_a_click_on_the_floor_walks_the_player_there() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await wait_physics_frames(12) # the view settles into its locked angle and the halls' navigation mesh bakes
	var target: Vector3 = player.global_position + Vector3(0.0, 0.0, -5.0)
	var pilot: DemoAutopilot = DemoAutopilot.new()
	pilot.player = player
	add_child_autofree(pilot)
	pilot.click(target)
	pilot.run()
	await wait_seconds(0.5)
	assert_true(player.is_navigating, "Off to where the click landed")
	await wait_seconds(2.5)
	assert_lt(player.global_position.distance_to(target), 1.5, "And there")


func test_fireball_hurts_what_it_lands_on() -> void:
	var ghoul: EnemyNpc = load("res://addons/3d_player_controller/scenes/demo/arpg/ghoul.tscn").instantiate()
	demo.add_child(ghoul)
	ghoul.global_position = player.global_position + Vector3(0.0, 0.0, -4.0)
	await wait_physics_frames(2)
	assert_gt(FIREBALL.damage, ghoul.health.max_health, "One bolt is more than a ghoul has")
	FIREBALL.impact(player, ghoul)
	await wait_physics_frames(1)
	assert_true(ghoul.is_dead, "Down in one")
	ghoul.queue_free()


func test_the_halls_wave_counts_and_a_ghoul_drops_gold() -> void:
	var spawner: WaveSpawner = demo.spawner
	demo._on_hall_body_entered(player)
	await wait_physics_frames(2)
	assert_eq(spawner.alive.size(), 4)
	var ghoul: EnemyNpc = spawner.alive[0]
	var at: Vector3 = ghoul.global_position
	for enemy: EnemyNpc in spawner.alive.duplicate():
		enemy.take_hit(500.0, player.global_position)
	await wait_physics_frames(2)
	assert_eq(player.quest_log.get_count(QUEST, &"clear_wave"), 1)
	var drops: Array[Node] = demo.find_children("*", "ItemPickup", false, false)
	assert_gte(drops.size(), 4, "Gold where each fell")
	var near: bool = false
	for drop: Node in drops:
		if (drop as ItemPickup).item == COIN and (drop as Node3D).global_position.distance_to(at) < 1.0:
			near = true
	assert_true(near)
	player.warp_to(Transform3D(Basis(), at))
	await wait_physics_frames(3)
	assert_gt(player.inventory.count_of(COIN), 0, "Walked over, it is in the bag")
	assert_gt(demo.gold_looted, 0)


func test_the_sigil_wakes_the_lord_and_his_death_ends_the_run() -> void:
	var lord: EnemyNpc = demo.lord
	demo._on_lair_body_entered(player)
	assert_eq(lord.target, player, "Awake")
	assert_eq(player.controls.boss_name_label.text, "Crypt Lord")
	for i: int in 3:
		player.quest_log.progress(&"clear_wave")
	lord.take_hit(5000.0, player.global_position)
	await wait_physics_frames(2)
	assert_true(player.quest_log.is_complete(QUEST))
	assert_eq(player.inventory.count_of(COIN), 200, "The crypt's reward")
