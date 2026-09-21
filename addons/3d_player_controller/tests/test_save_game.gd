extends GutTest

## Purpose: A SaveGame node writes every Saveable's state to one file and reads it back: the Player's position,
## checkpoint, pools and inventory, plus whatever else joined the group. The pause menu shows Save and Load
## only while a SaveGame is in the scene, checkpoints and the autosave timer write on their own, and a title
## screen's Continue request loads once the Player is in.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const SAVE_GAME_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/ui/save_game.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/prop/checkpoint.tscn")
const APPLE: Item = preload("res://addons/3d_player_controller/inventory/resources/items/apple.tres")
const TEST_PATH: String = "user://test_savegame.tres"

var root: Node3D
var player: Player
var saver: SaveGame


func before_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	root = Node3D.new()
	add_child_autofree(root)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(60.0, 1.0, 60.0)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	player = PLAYER_SCENE.instantiate()
	player.name = "Player"
	root.add_child(player)
	saver = SAVE_GAME_SCENE.instantiate()
	saver.save_path = TEST_PATH
	root.add_child(saver)
	await wait_physics_frames(3)


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	SaveGame.load_requested = false


func test_nothing_to_load_before_a_save() -> void:
	assert_false(saver.has_save())
	watch_signals(saver)
	assert_false(saver.load_game())
	assert_signal_emitted(saver, "load_failed")


func test_the_player_round_trips_through_the_file() -> void:
	player.warp_to(Transform3D(Basis(), Vector3(5.0, 0.0, -3.0)))
	player.set_checkpoint(Transform3D(Basis(), Vector3(9.0, 0.0, 9.0)))
	player.health.health = 42.0
	player.health.energy = 17.0
	player.enable_stamina = true # off, the bar refills itself every physics frame
	player.stamina.stamina = 33.0
	player.inventory.add_item(APPLE, 3)
	await wait_physics_frames(1)
	watch_signals(saver)
	assert_eq(saver.save_game(), OK)
	assert_signal_emitted(saver, "saved")
	assert_true(saver.has_save())
	var data: SaveGameData = ResourceLoader.load(TEST_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_true(data.states.has("Player"), "The Player is keyed by its path from the SaveGame's parent: %s" % data.states.keys())
	assert_false(data.saved_at.is_empty())

	player.warp_to(Transform3D(Basis(), Vector3.ZERO))
	player.set_checkpoint(Transform3D(Basis(), Vector3.ZERO))
	player.health.health = player.health.max_health
	player.health.energy = player.health.max_energy
	player.stamina.stamina = player.stamina.max_value
	player.inventory.remove_item(APPLE, 3)
	assert_eq(player.inventory.count_of(APPLE), 0)
	assert_true(saver.load_game())
	assert_signal_emitted(saver, "loaded")
	assert_almost_eq(player.global_position, Vector3(5.0, 0.0, -3.0), Vector3.ONE * 0.01)
	assert_almost_eq(player.respawn_transform.origin, Vector3(9.0, 0.0, 9.0), Vector3.ONE * 0.01)
	assert_eq(player.health.health, 42.0)
	assert_eq(player.health.energy, 17.0)
	assert_almost_eq(player.stamina.stamina, 33.0, 2.0, "Stamina is back, give or take a frame of regen")
	assert_eq(player.inventory.count_of(APPLE), 3, "The inventory comes back inside the same file")


func test_a_save_taken_dead_comes_back_alive() -> void:
	player.load_state({"health": 0.0})
	assert_eq(player.health.health, player.health.max_health)


func test_any_saveable_in_the_group_is_kept() -> void:
	var counter: SaveableCounter = SaveableCounter.new()
	counter.name = "Counter"
	root.add_child(counter)
	counter.count = 7
	saver.save_game()
	counter.count = 0
	saver.load_game()
	assert_eq(counter.count, 7)
	var data: SaveGameData = ResourceLoader.load(TEST_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_true(data.states.has("Counter"))


func test_a_saveable_that_is_gone_is_skipped() -> void:
	var counter: SaveableCounter = SaveableCounter.new()
	counter.name = "Counter"
	root.add_child(counter)
	counter.count = 3
	saver.save_game()
	counter.free()
	assert_true(saver.load_game(), "A missing node is no reason to fail")


func test_a_checkpoint_saves_the_game() -> void:
	var checkpoint: Checkpoint = CHECKPOINT_SCENE.instantiate()
	root.add_child(checkpoint)
	checkpoint.global_position = Vector3(10.0, 0.0, 0.0)
	watch_signals(saver)
	player.warp_to(Transform3D(Basis(), Vector3(10.0, 0.0, 0.0)))
	await wait_physics_frames(3)
	assert_signal_emitted(saver, "saved", "Taking a checkpoint writes the file")
	saver.delete_save()
	assert_false(saver.has_save())
	saver.save_on_checkpoint = false
	player.warp_to(Transform3D(Basis(), Vector3(20.0, 0.0, 0.0)))
	await wait_physics_frames(2)
	player.warp_to(Transform3D(Basis(), Vector3(10.0, 0.0, 0.0)))
	await wait_physics_frames(3)
	assert_false(saver.has_save(), "Turned off, a checkpoint writes nothing")


func test_autosave_writes_on_the_timer() -> void:
	saver.autosave_interval = 0.2
	assert_false(saver.autosave_timer.is_stopped())
	await wait_seconds(0.35)
	assert_true(saver.has_save())
	saver.autosave_interval = 0.0
	assert_true(saver.autosave_timer.is_stopped())


func test_the_pause_menu_offers_save_and_load() -> void:
	player.pause.show_menu()
	assert_true(player.pause.save_button.visible)
	assert_true(player.pause.load_button.visible)
	assert_true(player.pause.load_button.disabled, "Nothing to load yet")
	player.pause._on_save_pressed()
	assert_true(saver.has_save())
	assert_false(player.pause.visible, "Saving closes the menu")
	player.pause.show_menu()
	assert_false(player.pause.load_button.disabled)
	player.pause.hide_menu()


func test_the_pause_menu_hides_them_without_a_save_game() -> void:
	saver.free()
	player.pause.show_menu()
	assert_false(player.pause.save_button.visible)
	assert_false(player.pause.load_button.visible)
	player.pause.hide_menu()


func test_a_requested_load_happens_on_ready() -> void:
	player.warp_to(Transform3D(Basis(), Vector3(4.0, 0.0, 4.0)))
	saver.save_game()
	player.warp_to(Transform3D(Basis(), Vector3.ZERO))
	saver.free()
	SaveGame.load_requested = true
	var late: SaveGame = SAVE_GAME_SCENE.instantiate()
	late.save_path = TEST_PATH
	watch_signals(late)
	root.add_child(late)
	await wait_physics_frames(2)
	assert_signal_emitted(late, "loaded")
	assert_false(SaveGame.load_requested, "The request is consumed")
	assert_almost_eq(player.global_position, Vector3(4.0, 0.0, 4.0), Vector3.ONE * 0.01)


class SaveableCounter extends Node:
	var count: int = 0

	func _ready() -> void:
		add_to_group(SaveGame.GROUP)

	func save_state() -> Dictionary:
		return {"count": count}

	func load_state(state: Dictionary) -> void:
		count = int(state.get("count", 0))
