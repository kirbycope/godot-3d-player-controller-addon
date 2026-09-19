extends GutTest

## Purpose: The GTA demo is a playable slice on foot: the pistol on the sidewalk goes into the hand on a walk-over
## and fires a round, the clips feed it, a health pack heals the moment it is taken, the fixer's job counts the
## gang and the data card and pays cash, and the wanted meter puts officers on the street when the law is hurt and
## lets them go when the stars have faded.

const DEMO_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/demo/gta/gta_demo.tscn")
const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/gta_alley.tres")
const CASH: Item = preload("res://addons/3d_player_controller/resources/items/cash.tres")
const CLIP: Item = preload("res://addons/3d_player_controller/resources/items/pistol_clip.tres")
const HEALTH_PACK: Item = preload("res://addons/3d_player_controller/resources/items/health_pack.tres")
const DATA_CARD: Item = preload("res://addons/3d_player_controller/resources/items/data_card.tres")

var demo: Node3D
var player: Player
var wanted: WantedLevel


func before_each() -> void:
	demo = DEMO_SCENE.instantiate()
	add_child_autofree(demo)
	await wait_physics_frames(3)
	player = demo.player
	wanted = demo.wanted
	player.dialogue_screen.characters_per_second = 0.0


func after_each() -> void:
	# The InputMap outlives the scene, so put the pad back or this demo's layout is still on in the next
	# script: Dark Souls has no jump on a face button at all.
	if is_instance_valid(player):
		player.control_scheme = PlayerControls.DEFAULT_SCHEME


func test_the_demo_sets_the_player_up_for_gta() -> void:
	assert_eq(player.control_scheme, preload("res://addons/gta/resources/control_schemes/gta.tres"))
	assert_false(player.lock_on_enabled(), "Focus aims freely over the shoulder")
	assert_false(player.controls.contextual_only, "The whole HUD is on screen in a demo")
	assert_eq(player.controls.joypad_button_0_label.text, "Sprint", "A is Sprint on a GTA pad")
	assert_eq(player.controls.joypad_button_3_label.text, "Action")
	assert_true(demo.get_node("Sidewalk/Pistol") is Firearm)
	assert_true(demo.get_node("Lot/Rifle") is Rifle)
	assert_eq(demo.get_node("Lot/Gunmen").get_child_count(), 3)
	assert_eq(wanted.stars, 0)


func test_walking_over_the_pistol_arms_the_player_and_it_fires() -> void:
	var pickup: Firearm = demo.get_node("Sidewalk/Pistol")
	player.warp_to(Transform3D(Basis(), pickup.global_position))
	await wait_physics_frames(3)
	assert_true(player.equipped_pistol, "The pistol is in hand")
	assert_true(player.has_firearm_equipped)
	assert_eq(player.controls.joypad_axis_4_plus_label.text, "Aim", "The left trigger aims a gun")
	var pistol: Firearm = pickup.equipment_instance as Firearm
	assert_not_null(pistol, "The copy on the skeleton is the gun that fires")
	var rounds: int = pistol.rounds
	var round_fired: Projectile = pistol.fire()
	assert_not_null(round_fired, "A round left the muzzle")
	assert_eq(pistol.rounds, rounds - 1)
	if round_fired:
		round_fired.queue_free()


func test_clips_reload_the_pistol_from_the_inventory() -> void:
	var pickup: Firearm = demo.get_node("Sidewalk/Pistol")
	player.warp_to(Transform3D(Basis(), pickup.global_position))
	await wait_physics_frames(3)
	var pistol: Firearm = pickup.equipment_instance as Firearm
	player.inventory.add_item(CLIP, 2)
	assert_eq(pistol.reserve_rounds, 24, "Two clips are two magazines in reserve")
	pistol.rounds = 0
	pistol.reload()
	await wait_seconds(pistol.reload_time + 0.2)
	assert_eq(pistol.rounds, pistol.magazine_size, "A reload fills the magazine")
	assert_eq(player.inventory.count_of(CLIP), 1, "And spends a clip")


func test_a_health_pack_heals_the_moment_it_is_taken() -> void:
	player.health.health = 20.0
	var pack: ItemPickup = demo.get_node("Sidewalk/HealthPack")
	pack.player = player
	pack.take()
	await wait_physics_frames(1)
	assert_eq(player.health.health, 70.0, "Fifty back")
	assert_eq(player.inventory.count_of(HEALTH_PACK), 0, "It is not carried")


func test_the_fixers_job_counts_the_gang_and_the_card_and_pays_cash() -> void:
	var fixer: TalkingNpc = demo.get_node("People/Fixer")
	var log: QuestLog = player.quest_log
	assert_true(fixer.talk(player))
	await wait_process_frames(1)
	player.dialogue_screen._choice_buttons[0].pressed.emit()
	assert_true(log.is_active(QUEST), "Taking the job starts it")
	player.dialogue_screen.end()
	var gunmen: Array[Node] = demo.get_node("Lot/Gunmen").get_children()
	gunmen[0].take_hit(500.0, player.global_position)
	await wait_physics_frames(2)
	assert_eq(wanted.stars, 0, "The law is not there yet")
	gunmen[1].take_hit(500.0, player.global_position)
	gunmen[2].take_hit(500.0, player.global_position)
	await wait_physics_frames(2)
	assert_true(log.is_objective_done(QUEST, &"defeat_gunman"), "Three gunmen down")
	assert_eq(wanted.stars, 1, "The shooting heard from the street is an offence")
	var card: ItemPickup = demo.get_node("Lot/DataCard")
	card.player = player
	card.take()
	await wait_physics_frames(1)
	assert_true(log.is_complete(QUEST))
	assert_eq(player.inventory.count_of(CASH), 500, "The fixer pays")
	assert_eq(player.inventory.count_of(DATA_CARD), 1)


func test_hurting_the_law_raises_the_stars_and_they_fade_when_it_is_over() -> void:
	wanted.decay_seconds = 0.2
	wanted.raise(1)
	assert_eq(wanted.stars, 1)
	assert_eq(wanted.officers.size(), 1, "One officer per star")
	var officer: EnemyNpc = wanted.officers[0]
	assert_true(is_instance_valid(officer) and officer.get_parent() == demo, "Spawned into the scene")
	assert_gte(officer.global_position.distance_to(player.global_position), wanted.min_spawn_distance, "Off screen")
	var start: Vector3 = officer.global_position
	await wait_seconds(0.6)
	assert_lt(officer.global_position.distance_to(player.global_position), start.distance_to(player.global_position), "And closing in from there")
	officer.take_hit(500.0, player.global_position)
	await wait_physics_frames(2)
	assert_eq(wanted.stars, 2, "An officer down is another star")
	assert_eq(wanted.officers.size(), 1, "And another officer comes")
	assert_true(wanted.is_chased(), "Who is on the Player")
	await wait_seconds(0.5)
	assert_eq(wanted.stars, 2, "The stars hold while an officer has the Player in sight")
	wanted.officers[0].queue_free()
	await wait_seconds(0.7)
	assert_eq(wanted.stars, 0, "Lost, the stars fade one at a time")
	assert_eq(wanted.officers.size(), 0, "And no officer is left")


func test_a_prompt_lands_on_the_button_that_carries_action_in_the_gta_layout() -> void:
	var fixer: TalkingNpc = demo.get_node("People/Fixer")
	player.warp_to(Transform3D(Basis(), fixer.global_position + Vector3(1.0, 0.0, 1.0)))
	await wait_physics_frames(3)
	assert_eq(player.controls.joypad_button_3_label.text, "Talk", "Y is Action on a GTA pad, so Talk goes there")
	assert_eq(player.controls.joypad_button_0_label.text, "Sprint", "And A keeps its own word")
	assert_eq(player.controls.action_label(&"action"), player.controls.joypad_button_3_label)
