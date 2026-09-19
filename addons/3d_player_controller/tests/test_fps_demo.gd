extends GutTest

## Purpose: The FPS demo is a playable slice from the head: the camera starts in first person, the pistol off the
## desk goes into the hand, a health pack heals on touch, the armoury door refuses without the security card and
## opens with it, opening it brings a wave through the control room, and the lift ends the run.

const DEMO_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/demo/fps/fps_demo.tscn")
const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/fps_breakout.tres")
const CARD: Item = preload("res://addons/3d_player_controller/resources/items/security_card.tres")

var demo: Node3D
var player: Player


func before_each() -> void:
	demo = DEMO_SCENE.instantiate()
	add_child_autofree(demo)
	await wait_physics_frames(3)
	player = demo.player


func test_the_demo_starts_in_first_person_with_the_run_on() -> void:
	assert_eq((player.camera as Camera).perspective, Camera.Perspective.FIRST_PERSON)
	assert_true(player.quest_log.is_active(QUEST))
	assert_true(demo.get_node("Armoury/Door") is LockedDoor)
	assert_true(demo.get_node("WaveSpawner") is WaveSpawner)
	assert_eq(demo.get_node("Sentries").get_child_count(), 4)


func test_the_pistol_comes_off_the_desk() -> void:
	var pistol: Firearm = demo.get_node("CellBlock/Pistol")
	player.warp_to(Transform3D(Basis(), pistol.global_position + Vector3(0.0, -0.85, 0.6)))
	await wait_physics_frames(3)
	assert_true(player.equipped_pistol)


func test_the_door_refuses_without_the_card_and_opens_with_it() -> void:
	var door: LockedDoor = demo.get_node("Armoury/Door")
	var refused: Array = []
	door.refused.connect(func(_by: Player) -> void: refused.append(true))
	assert_false(door.open(player), "No card, no entry")
	assert_false(door.is_open)
	player.inventory.add_item(CARD, 1)
	player.quest_log.progress(&"find_card")
	assert_true(door.open(player))
	assert_true(door.is_open)
	assert_true(door.collision_shape.disabled, "The way is clear")
	assert_true(player.quest_log.is_objective_done(QUEST, &"open_door"))
	var spawner: WaveSpawner = demo.get_node("WaveSpawner")
	assert_false(spawner.running, "The alarm gives you a moment")
	await wait_seconds(demo.alarm_delay + 0.2)
	assert_true(spawner.running, "Then the wave is on its way")
	assert_eq(spawner.alive.size(), 3)
	assert_false(door.open(player), "A door opens once")


func test_the_door_prompt_reads_the_lock() -> void:
	var door: LockedDoor = demo.get_node("Armoury/Door")
	player.warp_to(Transform3D(Basis(), door.global_position + Vector3(1.5, 0.0, 0.0)))
	await wait_physics_frames(3)
	assert_eq(player.controls.joypad_button_1_label.text, "Card needed")
	player.inventory.add_item(CARD, 1)
	player.warp_to(Transform3D(Basis(), door.global_position + Vector3(6.0, 0.0, 0.0)))
	await wait_physics_frames(3)
	player.warp_to(Transform3D(Basis(), door.global_position + Vector3(1.5, 0.0, 0.0)))
	await wait_physics_frames(3)
	assert_eq(player.controls.joypad_button_1_label.text, "Open")
	var press: InputEventAction = InputEventAction.new()
	press.action = &"action"
	press.pressed = true
	Input.parse_input_event(press)
	await wait_physics_frames(3)
	var release: InputEventAction = InputEventAction.new()
	release.action = &"action"
	Input.parse_input_event(release)
	assert_true(door.is_open, "And the press opens it from there")
	assert_true(player.quest_log.is_objective_done(QUEST, &"open_door"))


func test_the_wave_clears_and_the_lift_ends_the_run() -> void:
	var spawner: WaveSpawner = demo.get_node("WaveSpawner")
	spawner.start()
	await wait_physics_frames(2)
	assert_eq(spawner.alive.size(), 3)
	var cleared: Array = []
	spawner.all_cleared.connect(func() -> void: cleared.append(true))
	for enemy: EnemyNpc in spawner.alive.duplicate():
		enemy.take_hit(500.0, player.global_position)
	await wait_physics_frames(2)
	assert_eq(cleared.size(), 1, "The last down clears the wave")
	assert_true(spawner.is_done())
	player.inventory.add_item(CARD, 1)
	player.quest_log.progress(&"find_card")
	player.quest_log.progress(&"open_door")
	demo._on_lift_body_entered(player)
	assert_true(player.quest_log.is_complete(QUEST))
