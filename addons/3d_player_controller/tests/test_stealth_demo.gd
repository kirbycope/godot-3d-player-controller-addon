extends GutTest

## Purpose: The stealth demo is a playable slice: guards walk their routes, a vision cone fills on a Player in
## view (slower for a crouched one, never for a stealthed one) and sets the guard and his fellows on them, loses
## them out of sight, a strike on an unaware guard lands ten times harder, and the orders and the gate are the run.

const DEMO_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/demo/stealth/stealth_demo.tscn")
const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/stealth_orders.tres")
const INTEL: Item = preload("res://addons/3d_player_controller/resources/items/intel.tres")

var demo: Node3D
var player: Player


func before_each() -> void:
	demo = DEMO_SCENE.instantiate()
	add_child_autofree(demo)
	await wait_physics_frames(3)
	player = demo.player


func test_guards_patrol_their_routes() -> void:
	var guard: EnemyNpc = demo.get_node("Guards/Guard3")
	assert_not_null(guard.patrol_points)
	var start: Vector3 = guard.global_position
	player.warp_to(Transform3D(Basis(), Vector3(0.0, 0.0, 40.0))) # well out of every cone
	await wait_seconds(guard.patrol_wait + 2.0) # the first point is where he stands; the pause there, then the walk
	assert_gt(guard.global_position.distance_to(start), 0.8, "On his way to the next point")
	assert_null(guard.target, "Nobody to hunt")


func test_a_cone_fills_on_a_player_in_view_and_raises_the_alarm() -> void:
	var guard: EnemyNpc = demo.get_node("Guards/Guard2")
	var cone: VisionCone = guard.get_node("VisionCone")
	var others: EnemyNpc = demo.get_node("Guards/Guard1")
	player.warp_to(Transform3D(Basis(), guard.global_position - guard.global_basis.z * 6.0))
	await wait_physics_frames(3)
	assert_true(cone.can_see(player), "Six metres in front, in the open")
	await wait_seconds(cone.detect_seconds + 0.3)
	assert_eq(guard.target, player, "Spotted")
	assert_eq(others.target, player, "And the alarm brought the others")
	assert_eq(demo.alarms, 1)


func test_crouching_halves_the_range_and_stealth_hides_outright() -> void:
	var guard: EnemyNpc = demo.get_node("Guards/Guard2")
	var cone: VisionCone = guard.get_node("VisionCone")
	player.warp_to(Transform3D(Basis(), guard.global_position - guard.global_basis.z * (cone.range_metres * 0.8)))
	await wait_physics_frames(3)
	assert_true(cone.can_see(player), "Standing at eighty percent of the range: seen")
	player.is_crouching = true
	assert_false(cone.can_see(player), "Crouched: out of the halved range")
	player.is_crouching = false
	player.is_stealthed = true
	assert_false(cone.can_see(player), "Stealthed: never")
	player.is_stealthed = false


func test_out_of_sight_long_enough_the_guard_gives_up() -> void:
	var guard: EnemyNpc = demo.get_node("Guards/Guard2")
	var cone: VisionCone = guard.get_node("VisionCone")
	cone.lose_seconds = 0.4
	guard.aggro(player)
	player.warp_to(Transform3D(Basis(), Vector3(0.0, 0.0, 40.0)))
	await wait_seconds(0.8)
	assert_null(guard.target, "Lost")
	assert_true(guard.is_returning_home or guard.global_position.distance_to(guard._spawn_transform.origin) < 0.6, "And back at his post, or on the way")


func test_a_strike_on_an_unaware_guard_is_a_takedown() -> void:
	var guard: EnemyNpc = demo.get_node("Guards/Guard1")
	var sword: Equipment = demo.get_node("Dressing/Sword")
	player.warp_to(Transform3D(Basis(), sword.global_position))
	await wait_physics_frames(3)
	guard.register_weapon_hit(player.inventory.get_all_weapons()[0], player)
	await wait_physics_frames(2)
	assert_true(guard.is_dead, "Ten times the damage: down in one")
	var aware: EnemyNpc = demo.get_node("Guards/Guard3")
	aware.aggro(player)
	aware.register_weapon_hit(player.inventory.get_all_weapons()[0], player)
	assert_false(aware.is_dead, "A guard already hunting you takes an ordinary hit")


func test_the_orders_and_the_gate_are_the_run() -> void:
	var intel: ItemPickup = demo.get_node("Dressing/Intel")
	intel.player = player
	intel.take()
	await wait_physics_frames(1)
	assert_true(player.quest_log.is_objective_done(QUEST, &"take_orders"))
	demo._on_exit_body_entered(player)
	assert_true(player.quest_log.is_complete(QUEST))
