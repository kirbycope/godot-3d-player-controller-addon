extends GutTest

## Purpose: The TPS demo is a playable slice over the shoulder: the free-aim layout, a rifle and pistol at the
## start, waves that begin when the sandbags are reached and are counted by the quest as they fall, a sealed gate
## that opens when the last wave is down, and the extraction pad that ends the run.

const DEMO_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/demo/tps/tps_demo.tscn")
const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/tps_holdout.tres")

var demo: Node3D
var player: Player


func before_each() -> void:
	demo = DEMO_SCENE.instantiate()
	add_child_autofree(demo)
	await wait_physics_frames(3)
	player = demo.player


func test_the_demo_sets_the_player_up_for_a_shooter_over_the_shoulder() -> void:
	assert_eq(player.control_scheme, preload("res://addons/gta/resources/control_schemes/gta.tres"), "Free aim over the shoulder")
	assert_false(player.lock_on_enabled())
	assert_true(player.quest_log.is_active(QUEST))
	assert_true(demo.get_node("Gear/Rifle") is Rifle)
	assert_true(demo.get_node("Gate") is LockedDoor)
	assert_false(demo.get_node("Gate").is_open, "Sealed until the waves are done")


func test_reaching_the_sandbags_starts_the_waves_and_the_last_one_opens_the_gate() -> void:
	var spawner: WaveSpawner = demo.get_node("WaveSpawner")
	demo._on_hold_position_body_entered(player)
	await wait_physics_frames(2)
	assert_true(spawner.running)
	assert_eq(spawner.alive.size(), 3, "Three over the wall first")
	for i: int in 3:
		for enemy: EnemyNpc in spawner.alive.duplicate():
			enemy.take_hit(500.0, player.global_position)
		await wait_physics_frames(2)
		assert_eq(player.quest_log.get_count(QUEST, &"clear_wave"), i + 1, "Wave %d counted" % (i + 1))
		if i < 2:
			spawner._next_wave() # rather than the wait between waves
			await wait_physics_frames(2)
			assert_eq(spawner.alive.size(), [4, 5][i], "The next wave is bigger")
	assert_true(spawner.is_done())
	var gate: LockedDoor = demo.get_node("Gate")
	assert_true(gate.is_open, "The gate opens on the last one down")
	demo._on_extraction_body_entered(player)
	assert_true(player.quest_log.is_complete(QUEST))


func test_the_gate_reads_sealed_and_refuses_until_the_script_clears_it() -> void:
	var gate: LockedDoor = demo.get_node("Gate")
	player.warp_to(Transform3D(Basis(), gate.global_position + Vector3(0.0, 0.0, 1.6)))
	await wait_physics_frames(3)
	assert_eq(player.controls.action_label(&"action").text, "Sealed")
	assert_false(gate.open(player), "No key opens a sealed door")
	gate.sealed = false
	assert_true(gate.open(player), "Unsealed, it needs no key at all")
