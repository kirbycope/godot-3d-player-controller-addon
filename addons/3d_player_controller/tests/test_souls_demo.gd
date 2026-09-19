extends GutTest

## Purpose: The Souls demo is a playable slice: a tap of Sprint rolls and the roll's first frames take no hit, every
## swing and roll draws on the stamina bar, resting at the bonfire heals, refills the flasks and stands the hollows
## back up at their posts, the souls the dead leave drop where the Player falls and can be picked up again, and
## the fog gate wakes the boss.

const DEMO_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/demo/souls/souls_demo.tscn")
const SOULS: Item = preload("res://addons/3d_player_controller/resources/items/souls.tres")
const POTION: Item = preload("res://addons/3d_player_controller/resources/items/red_potion.tres")

var demo: Node3D
var player: Player


func before_each() -> void:
	demo = DEMO_SCENE.instantiate()
	add_child_autofree(demo)
	await wait_physics_frames(3)
	player = demo.player


func after_each() -> void:
	_send(&"sprint", false)
	_send(&"focus", false)


func _send(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func test_the_demo_sets_the_player_up_for_souls() -> void:
	assert_eq(player.control_scheme, preload("res://addons/3d_player_controller/resources/control_schemes/totk.tres"), "Lock-on Focus")
	assert_true(player.enable_stamina)
	assert_true(player.enable_dodge)
	assert_gt(player.attack_stamina_cost, 0.0, "Swings cost breath")
	assert_true(demo.get_node("Bonfire") is Bonfire)
	assert_true(demo.get_node("Enemies/Gravelord").is_boss)
	assert_eq(demo.get_node("Enemies/Hollows").get_child_count(), 3)


func test_a_tap_of_sprint_rolls_and_the_roll_takes_no_hit() -> void:
	var stamina_before: float = player.stamina.stamina
	_send(&"sprint", true)
	await wait_physics_frames(2)
	_send(&"sprint", false)
	await wait_physics_frames(2)
	assert_eq(player.current_state, NodeStateMachine.States.DODGING, "A tap is a roll")
	assert_true(player.is_dodging)
	assert_true(player.dodge_invulnerable, "The first frames of it take no hit")
	assert_almost_eq(player.stamina.stamina, stamina_before - player.dodge_stamina_cost, 0.5, "And it costs breath")
	var health_before: float = player.health.health
	player.take_hit(30.0, player.global_position + Vector3.FORWARD)
	assert_eq(player.health.health, health_before, "Rolled through it")
	await wait_seconds(player.dodge_iframe_seconds + 0.1)
	assert_false(player.dodge_invulnerable, "The frames run out")
	await wait_until(func() -> bool: return player.current_state != NodeStateMachine.States.DODGING, 3.0)
	assert_ne(player.current_state, NodeStateMachine.States.DODGING, "The roll ends on its own")


func test_a_held_sprint_is_a_sprint_not_a_roll() -> void:
	_send(&"sprint", true)
	await wait_seconds(player.dodge_tap_seconds + 0.1)
	_send(&"sprint", false)
	await wait_physics_frames(2)
	assert_ne(player.current_state, NodeStateMachine.States.DODGING, "Held past the tap, it was a sprint")


func test_a_swing_spends_stamina() -> void:
	var sword: Equipment = demo.get_node("Gear/BronzeSword")
	player.warp_to(Transform3D(Basis(), sword.global_position))
	await wait_physics_frames(3)
	var before: float = player.stamina.stamina
	_send(&"attack", true)
	await wait_physics_frames(2)
	_send(&"attack", false)
	await wait_physics_frames(1)
	assert_eq(player.current_state, NodeStateMachine.States.ATTACKING)
	assert_almost_eq(player.stamina.stamina, before - player.attack_stamina_cost, 2.0, "Less the regen of a few frames")


func test_resting_at_the_bonfire_heals_refills_the_flasks_and_revives_the_hollows() -> void:
	var bonfire: Bonfire = demo.get_node("Bonfire")
	var hollow: EnemyNpc = demo.get_node("Enemies/Hollows/Hollow1")
	var post: Vector3 = hollow.global_position
	hollow.global_position += Vector3(3.0, 0.0, 0.0)
	hollow.take_hit(500.0, player.global_position)
	await wait_physics_frames(2)
	assert_true(hollow.is_dead)
	player.health.health = 25.0
	player.inventory.remove_item(POTION, player.inventory.count_of(POTION))
	bonfire.rest(player)
	await wait_physics_frames(2)
	assert_eq(player.health.health, player.health.max_health, "Healed")
	assert_eq(player.inventory.count_of(POTION), bonfire.flasks, "Flasks topped up")
	assert_false(hollow.is_dead, "The hollow is up again")
	assert_almost_eq(hollow.global_position.distance_to(post), 0.0, 0.1, "At its post")
	assert_true(player.respawn_transform.origin.distance_to(bonfire.global_position) < 4.0, "The fire is the checkpoint")


func test_the_souls_drop_where_you_die_and_come_back_with_a_pickup() -> void:
	player.inventory.add_item(SOULS, 120)
	player.warp_to(Transform3D(Basis(), Vector3(0.0, 0.0, -20.0)))
	await wait_physics_frames(2)
	player.health.damage(1000.0, Vector3.ZERO)
	await wait_physics_frames(2)
	assert_eq(player.inventory.count_of(SOULS), 0, "Dropped")
	var stain: ItemPickup = demo.bloodstain
	assert_not_null(stain, "A bloodstain marks the spot")
	if stain:
		assert_eq(stain.count, 120)
		assert_lt(stain.global_position.distance_to(Vector3(0.0, 0.0, -20.0)), 1.0)
		stain.player = player
		stain.take()
		await wait_physics_frames(1)
		assert_eq(player.inventory.count_of(SOULS), 120, "And they are back")


func test_the_fog_gate_wakes_the_boss() -> void:
	var boss: EnemyNpc = demo.get_node("Enemies/Gravelord")
	assert_null(boss.target)
	demo._on_fog_gate_body_entered(player)
	assert_eq(boss.target, player, "Through the fog, the boss is on you")
	assert_eq(player.boss_bar.name_label.text, "Gravelord Vessel", "And its bar is up")


func test_the_sword_lands_on_a_hollow_with_focus_held() -> void:
	var sword: Equipment = demo.get_node("Gear/BronzeSword")
	player.warp_to(Transform3D(Basis(), sword.global_position))
	await wait_physics_frames(3)
	var hollow: EnemyNpc = demo.get_node("Enemies/Hollows/Hollow1")
	hollow.global_position = player.global_position + Vector3(0.0, 0.0, -1.4)
	await wait_physics_frames(2)
	var before: float = hollow.health.health
	_send(&"focus", true)
	await wait_physics_frames(6)
	for i: int in 4:
		_send(&"attack", true)
		await wait_physics_frames(4)
		_send(&"attack", false)
		await wait_seconds(0.7)
	_send(&"focus", false)
	assert_lt(hollow.health.health, before, "A swing connected")


func test_the_greatsword_comes_off_the_altar_into_both_hands() -> void:
	var sword: Equipment = demo.get_node("Gear/BronzeSword")
	player.warp_to(Transform3D(Basis(), sword.global_position))
	await wait_physics_frames(3)
	var altar: Node3D = demo.get_node("Gear/Altar")
	player.warp_to(Transform3D(Basis(), altar.global_position + Vector3(0.0, -0.45, 1.3)))
	await wait_physics_frames(4)
	assert_true(player.equipped_sword_2h, "The greatsword is in hand")
	assert_false(player.equipped_sword_1h, "The one-handed sword is stowed")
