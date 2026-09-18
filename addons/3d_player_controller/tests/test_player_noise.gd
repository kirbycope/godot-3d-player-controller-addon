extends GutTest

## Purpose: how loud the Player is. Standing still is silence, crouching is near silence, sprinting is loud,
## and a gunshot or a landing spikes the reading and falls back. Whatever is inside the audible distance is
## told to come looking, and the HUD meter follows the reading.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/enemy_npc.tscn")
const METER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/noise_meter.tscn")

var root: Node3D
var player: Player
var noise: PlayerNoise


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	noise = player.get_node("PlayerNoise") as PlayerNoise
	await wait_physics_frames(2)


func test_standing_still_is_silence() -> void:
	player.velocity = Vector3.ZERO
	await wait_physics_frames(3)
	assert_almost_eq(noise.moving_level(), 0.0, 0.001, "A Player who is not moving makes no noise")


func test_crouching_is_quieter_than_walking_at_the_same_pace() -> void:
	player.velocity = Vector3(3.0, 0.0, 0.0)
	player.is_crouching = false
	var walking: float = noise.moving_level()
	player.is_crouching = true
	var sneaking: float = noise.moving_level()

	assert_gt(walking, sneaking, "The same pace crouched is quieter")
	assert_lt(sneaking, 0.1, "and a sneak is close to silent")


func test_sprinting_is_the_loudest_way_to_move() -> void:
	player.velocity = Vector3(5.5, 0.0, 0.0)
	player.is_crouching = false
	player.is_sprinting = false
	var walking: float = noise.moving_level()
	player.is_sprinting = true
	var sprinting: float = noise.moving_level()

	assert_gt(sprinting, walking, "Sprinting is louder than the same speed at a walk")
	assert_almost_eq(sprinting, noise.sprinting_level, 0.05, "and at full pace it reads about the sprint ceiling")


func test_stealth_takes_the_edge_off() -> void:
	player.velocity = Vector3(4.0, 0.0, 0.0)
	var plain: float = noise.moving_level()
	player.is_stealthed = true
	var hidden: float = noise.moving_level()

	assert_lt(hidden, plain, "Stealth quiets the footfall")


func test_a_one_off_noise_spikes_and_falls_back() -> void:
	noise.make_noise(1.0)
	await wait_physics_frames(2)
	var spiked: float = noise.level
	await wait_seconds(0.6)
	var later: float = noise.level

	assert_gt(spiked, 0.4, "A gunshot is heard at once")
	assert_lt(later, spiked, "and fades rather than hanging there")


func test_a_gunshot_carries_further_than_a_sneak() -> void:
	player.is_crouching = true
	player.velocity = Vector3(1.0, 0.0, 0.0)
	await wait_physics_frames(4)
	var sneaking_reach: float = noise.audible_distance()

	noise.make_noise(noise.firearm_noise)
	await wait_physics_frames(4)
	var shot_reach: float = noise.audible_distance()

	assert_gt(shot_reach, sneaking_reach * 3.0, "A shot carries far further than a sneak")
	assert_almost_eq(shot_reach, noise.hearing_range, noise.hearing_range * 0.35,
		"and a shot at full level carries about the whole hearing range")


func test_an_enemy_in_earshot_comes_looking_and_one_out_of_it_does_not() -> void:
	var near: EnemyNpc = ENEMY_SCENE.instantiate()
	var far: EnemyNpc = ENEMY_SCENE.instantiate()
	root.add_child(near)
	root.add_child(far)
	# Both stand clear of the enemy's own 4.5m sight aggro, so only hearing can explain either result
	near.global_position = player.global_position + Vector3(10.0, 0.0, 0.0)
	far.global_position = player.global_position + Vector3(0.0, 0.0, 28.0)
	await wait_physics_frames(3)
	assert_null(near.target, "Nobody is hunting yet")

	noise.make_noise(0.5)   # carries 15m at the default range
	await wait_seconds(0.5)

	assert_eq(near.target, player, "The one in earshot heard it")
	assert_null(far.target, "The one out of earshot did not")


func test_a_sneaking_player_wakes_nobody() -> void:
	var enemy: EnemyNpc = ENEMY_SCENE.instantiate()
	root.add_child(enemy)
	enemy.global_position = player.global_position + Vector3(8.0, 0.0, 0.0)   # outside its own sight aggro
	player.is_crouching = true
	player.velocity = Vector3(1.0, 0.0, 0.0)
	await wait_seconds(0.6)

	assert_null(enemy.target, "A sneak at eight metres goes unheard")


func test_the_meter_follows_the_reading() -> void:
	var meter: Control = METER_SCENE.instantiate()
	add_child_autofree(meter)
	var line: NoiseMeter = meter.get_node("Line") as NoiseMeter
	line.noise = noise
	await wait_physics_frames(1)

	noise.make_noise(0.8)
	await wait_physics_frames(3)

	assert_gt(line.level, 0.0, "The drawn level follows PlayerNoise")
	assert_almost_eq(line.level, noise.level, 0.001, "and is the same reading, not a second opinion")
