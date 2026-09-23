extends GutTest

## Purpose: A SaveGame node writes every Saveable's state to one file and reads it back: the Player's position,
## checkpoint, pools and inventory, plus whatever else joined the group. The file is plain JSON of one version,
## with no object in it, and anything else (an old .tres save, another version) is refused. The pause menu shows
## Save and Load only while a SaveGame is in the scene, checkpoints and the autosave timer write on their own, and
## a title screen's Continue request loads once the Player is in, including a Player spawned by a PlayerSpawner
## that sits before the SaveGame and spawns in its own _ready.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const SAVE_GAME_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/ui/save_game.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/prop/checkpoint.tscn")
const PLAYER_SPAWNER: Script = preload("res://addons/3d_player_controller/scripts/player_spawner.gd")
const APPLE: Item = preload("res://addons/3d_player_controller/inventory/resources/items/apple.tres")
const SWORD: Item = preload("res://addons/3d_player_controller/inventory/resources/items/wooden_sword.tres")
const TEST_PATH: String = "user://test_savegame.json"

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
	var data: Dictionary = saver.read_save()
	assert_eq(data["version"], SaveGame.VERSION)
	assert_true(data["states"].has("Player"), "The Player is keyed by its path from the SaveGame's parent: %s" % data["states"].keys())
	assert_false(str(data["saved_at"]).is_empty())
	var text: String = FileAccess.get_file_as_string(TEST_PATH)
	assert_not_null(JSON.to_native(JSON.parse_string(text)), "Plain JSON that reads back with objects refused, so it holds none")
	assert_string_contains(text, "apple.tres", "The inventory's item is written as its res:// path")

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


## The game's save carries the inventory's weapons as well as its stacks: one with a scene of its own by that scene,
## and one standing in the level as a model file with the Equipment script put on there by the pickup it came from,
## since the model file alone would load back as nothing.
func test_the_inventorys_weapons_round_trip_through_the_file() -> void:
	var model: Node = (load("res://addons/3d_player_controller/assets/quaternius/paraglider/Paraglider.glb") as PackedScene).instantiate()
	model.set_script(load("res://addons/3d_player_controller/scripts/equipment.gd"))
	var axe: Equipment = model as Equipment
	axe.name = "WorldAxe"
	axe.equipment_type = Equipment.EquipmentType.AXE_1H
	axe.bone_attachment_bone_name = "LeftHand"
	root.add_child(axe)
	assert_true(axe.equip(player), "The Player picks up the level's axe")
	player.inventory.add_item(SWORD)
	player.inventory.stow_equipment(player.inventory.get_equipment_by_type(Equipment.EquipmentType.AXE_1H))
	assert_eq(saver.save_game(), OK)
	assert_string_contains(FileAccess.get_file_as_string(TEST_PATH), String(axe.get_path()), "The axe is written as the pickup it came from")
	player.inventory.apply_save(InventorySave.new()) # everything gone
	assert_eq(player.inventory.get_all_weapons().size(), 0)
	assert_true(saver.load_game())
	assert_true(player.inventory.has_equipment(Equipment.EquipmentType.SWORD_1H), "The sword is back in hand")
	var weapons: Array[Equipment] = player.inventory.get_all_weapons()
	assert_eq(weapons.size(), 2, "and the axe is back too")
	var axes: Array[Equipment] = weapons.filter(func(w: Equipment) -> bool: return w.equipment_type == Equipment.EquipmentType.AXE_1H)
	assert_eq(axes.size(), 1)
	if axes.size() == 1:
		assert_false(player.inventory.equipment.has(axes[0]), "stowed, as it was saved")


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
	assert_true(saver.read_save()["states"].has("Counter"))


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


## Continue on a world that spawns its Player: the PlayerSpawner sits before the SaveGame and spawns in its own
## _ready, before the SaveGame's, and its local_player_spawned is wired to load_for_player before anything readies,
## as a scene's connection is. The load still happens.
func test_a_requested_load_waits_for_a_spawner_that_comes_first() -> void:
	var first: Node3D = _spawner_world()
	root.add_child(first)
	await wait_physics_frames(2)
	var spawned: Player = first.get_node("PlayerSpawner").get_local_player()
	assert_not_null(spawned, "The spawner spawned this peer's Player")
	spawned.warp_to(Transform3D(Basis(), Vector3(6.0, 0.0, -2.0)))
	assert_eq((first.get_node("SaveGame") as SaveGame).save_game(), OK)
	first.free()

	SaveGame.load_requested = true
	var world: Node3D = _spawner_world()
	var late: SaveGame = world.get_node("SaveGame")
	watch_signals(late)
	root.add_child(world)
	await wait_physics_frames(2)
	assert_signal_emitted(late, "loaded", "The load happened although the spawn came before the SaveGame readied")
	assert_false(SaveGame.load_requested, "The request is consumed")
	var player_now: Player = world.get_node("PlayerSpawner").get_local_player()
	assert_almost_eq(player_now.global_position, Vector3(6.0, 0.0, -2.0), Vector3.ONE * 0.01)


## A world with the spawner ahead of the SaveGame, the spawner's local_player_spawned wired to it before either readies.
func _spawner_world() -> Node3D:
	var world: Node3D = Node3D.new()
	world.name = "World"
	var spawner: PlayerSpawner = PLAYER_SPAWNER.new()
	spawner.name = "PlayerSpawner"
	spawner.add_child(PLAYER_SCENE.instantiate())
	world.add_child(spawner)
	var world_saver: SaveGame = SAVE_GAME_SCENE.instantiate()
	world_saver.name = "SaveGame"
	world_saver.save_path = TEST_PATH
	world.add_child(world_saver)
	spawner.local_player_spawned.connect(world_saver.load_for_player)
	return world


## A save from before the format changed (a SaveGameData .tres) is refused, not loaded through ResourceLoader.
func test_an_old_resource_save_is_refused() -> void:
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string('[gd_resource type="Resource" format=3]

[resource]
version = 1
states = {}
')
	file.close()
	watch_signals(saver)
	assert_false(saver.load_game())
	assert_signal_emitted(saver, "load_failed")
	assert_true(saver.read_save().is_empty())


## A save of another version is left alone rather than guessed at.
func test_another_version_is_refused() -> void:
	player.warp_to(Transform3D(Basis(), Vector3(3.0, 0.0, 3.0)))
	saver.save_game()
	var data: Variant = JSON.to_native(JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH)))
	data["version"] = SaveGame.VERSION + 1
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(JSON.from_native(data)))
	file.close()
	player.warp_to(Transform3D(Basis(), Vector3.ZERO))
	assert_false(saver.load_game(), "A newer file is refused")
	assert_almost_eq(player.global_position, Vector3.ZERO, Vector3.ONE * 0.01, "and nothing of it applied")


## The default path is a static var a test run can point elsewhere; new SaveGames and has_save_at follow it.
func test_the_default_path_can_be_redirected() -> void:
	var was: String = SaveGame.DEFAULT_SAVE_PATH
	SaveGame.DEFAULT_SAVE_PATH = TEST_PATH
	var redirected: SaveGame = SAVE_GAME_SCENE.instantiate()
	assert_eq(redirected.save_path, TEST_PATH, "A new SaveGame takes the redirected default")
	redirected.free()
	saver.save_game()
	assert_true(SaveGame.has_save_at(), "and has_save_at looks there by default")
	SaveGame.DEFAULT_SAVE_PATH = was


class SaveableCounter extends Node:
	var count: int = 0

	func _ready() -> void:
		add_to_group(SaveGame.GROUP)

	func save_state() -> Dictionary:
		return {"count": count}

	func load_state(state: Dictionary) -> void:
		count = int(state.get("count", 0))
