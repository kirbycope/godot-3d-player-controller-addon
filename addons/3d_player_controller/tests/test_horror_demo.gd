extends GutTest

## Purpose: The horror demo is a playable slice: the flashlight toggles on its action and runs its battery down,
## a battery picked up goes straight into it, the thing in the dark stands still while the beam is on it and moves
## again when it is off, the cellar door needs the key, and the key and the door are the run.

const DEMO_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/demo/horror/horror_demo.tscn")
const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/horror_cellar.tres")
const BATTERY: Item = preload("res://addons/3d_player_controller/resources/items/battery.tres")
const CELLAR_KEY: Item = preload("res://addons/3d_player_controller/resources/items/cellar_key.tres")

var demo: Node3D
var player: Player
var flashlight: Flashlight


func before_each() -> void:
	demo = DEMO_SCENE.instantiate()
	add_child_autofree(demo)
	await wait_physics_frames(6) # the first scene of a run needs a few frames before its input reaches the torch
	player = demo.player
	flashlight = demo.flashlight


func after_each() -> void:
	# The InputMap outlives the scene, so put the pad back or this demo's layout is still on in the next
	# script: Dark Souls has no jump on a face button at all.
	if is_instance_valid(player):
		player.control_scheme = PlayerControls.DEFAULT_SCHEME


func _send(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func test_the_flashlight_is_on_the_dpad_and_toggles_with_its_action() -> void:
	assert_eq(player.controls.action_button_12, &"flashlight", "D-pad down is the torch for this run")
	assert_eq(player.controls.joypad_button_12_label.text, "Flashlight")
	assert_false(flashlight.is_on)
	_send(&"flashlight", true)
	await wait_physics_frames(2)
	_send(&"flashlight", false)
	assert_true(flashlight.is_on, "On")
	assert_true(flashlight.visible)
	var before: float = flashlight.battery
	await wait_seconds(0.5)
	assert_lt(flashlight.battery, before, "And running down")
	_send(&"flashlight", true)
	await wait_physics_frames(2)
	_send(&"flashlight", false)
	assert_false(flashlight.is_on, "Off again")


func test_a_battery_goes_straight_into_the_torch() -> void:
	flashlight.battery = 10.0
	var pickup: ItemPickup = demo.get_node("Dressing/Battery1")
	pickup.player = player
	pickup.take()
	await wait_physics_frames(1)
	assert_eq(player.inventory.count_of(BATTERY), 0, "Not carried")
	assert_almost_eq(flashlight.battery, 40.0, 0.1, "Thirty seconds more light")
	assert_eq(demo.stalker.target, player, "And the thing in the dark has noticed you")


func test_the_thing_freezes_in_the_beam_and_moves_in_the_dark() -> void:
	var stalker: EnemyNpc = demo.stalker
	player.warp_to(Transform3D(Basis(), stalker.global_position + Vector3(0.0, 0.0, -6.0)))
	await wait_physics_frames(2)
	player.camera_mount.rotation = Vector3(0.0, PI, 0.0) # looking back along +Z, at it
	flashlight.is_on = true
	await wait_physics_frames(3)
	assert_true(flashlight.lights(stalker), "In the beam")
	assert_eq(stalker.movement_scale, 0.0, "And frozen")
	flashlight.is_on = false
	await wait_physics_frames(3)
	assert_false(flashlight.lights(stalker))
	assert_eq(stalker.movement_scale, 1.0, "Free to move in the dark")


func test_the_door_needs_the_key_and_the_key_and_the_door_are_the_run() -> void:
	var door: LockedDoor = demo.door
	assert_false(door.open(player), "Locked without the key")
	var key: ItemPickup = demo.get_node("Dressing/CellarKey")
	key.player = player
	key.take()
	await wait_physics_frames(1)
	assert_true(player.quest_log.is_objective_done(QUEST, &"find_key"))
	assert_true(door.open(player), "The key opens it")
	demo._on_exit_body_entered(player)
	assert_true(player.quest_log.is_complete(QUEST))


func test_a_page_reads_on_action() -> void:
	var note: Readable = demo.get_node("Dressing/Note1")
	player.dialogue_screen.characters_per_second = 0.0
	assert_true(note.open(player))
	assert_true(player.dialogue_screen.visible)
	player.dialogue_screen.end()
	await wait_process_frames(1)
	assert_false(player.dialogue_screen.visible)
