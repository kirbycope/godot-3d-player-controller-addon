extends GutTest

## Purpose: The Player answers to one of two pad layouts. Zelda is the scene's own: A is Action, B Sprint,
## X Attack, Y Jump, and Focus locks on. GTA, which ships with the gta addon rather than here, moves the face
## buttons about (A Sprint, B Attack, X Jump,
## Y Action) and makes Focus a free over-the-shoulder aim. The switch works mid-game, from the export or
## from the saved settings, and the buttons come off the actions they used to stand for.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")

var player: Player
var _had_file: bool = false
var _backup: PackedByteArray = PackedByteArray()


## The settings are read off user://settings.tres on ready and the menu writes it, so the real file is put aside
## for the test and put back afterwards, the way test_settings_persistence does.
func before_each() -> void:
	_had_file = FileAccess.file_exists(PlayerSettingsResource.SAVE_PATH)
	if _had_file:
		_backup = FileAccess.get_file_as_bytes(PlayerSettingsResource.SAVE_PATH)
		DirAccess.remove_absolute(PlayerSettingsResource.SAVE_PATH)
	PlayerSettingsResource._cached = null
	var root := Node3D.new()
	add_child_autofree(root)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(20.0, 1.0, 20.0)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await wait_physics_frames(2)


func after_each() -> void:
	# Registrations are static, so they outlive the scene too and would leak into the next script
	PlayerControls.forget_registered_schemes()
	# The InputMap outlives the scene: put the pad back the way the other suites expect it
	if is_instance_valid(player):
		player.control_scheme = preload("res://addons/3d_player_controller/resources/control_schemes/totk.tres")
	if _had_file:
		var file: FileAccess = FileAccess.open(PlayerSettingsResource.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(_backup)
		file.close()
	elif FileAccess.file_exists(PlayerSettingsResource.SAVE_PATH):
		DirAccess.remove_absolute(PlayerSettingsResource.SAVE_PATH)
	PlayerSettingsResource._cached = null


func _has_button(action: StringName, button: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false


func test_zelda_is_the_default_layout() -> void:
	assert_eq(player.control_scheme, preload("res://addons/3d_player_controller/resources/control_schemes/totk.tres"))
	# Tears of the Kingdom's own layout. Its labels are Nintendo's, whose A is the right button and B the
	# bottom, mirrored from the Xbox naming Godot uses: the game's "A Action" is JOY_BUTTON_B here and its
	# "B Dash" is JOY_BUTTON_A.
	assert_true(_has_button(&"sprint", JOY_BUTTON_A), "The bottom button dashes, as B does in the game")
	assert_true(_has_button(&"action", JOY_BUTTON_B), "The right button is Action, as A is in the game")
	assert_true(_has_button(&"attack", JOY_BUTTON_X), "The left button attacks, as Y does in the game")
	assert_true(_has_button(&"jump", JOY_BUTTON_Y), "The top button jumps, as X does in the game")
	assert_true(player.lock_on_enabled(), "Zelda locks on")
	assert_eq(player.controls.joypad_button_0_label.text, "Sprint")


func test_gta_moves_the_face_buttons_and_frees_the_aim() -> void:
	player.control_scheme = preload("res://addons/gta/resources/control_schemes/gta.tres")
	assert_true(_has_button(&"sprint", JOY_BUTTON_A), "A is Sprint")
	assert_true(_has_button(&"attack", JOY_BUTTON_B), "B is Attack")
	assert_true(_has_button(&"jump", JOY_BUTTON_X), "X is Jump")
	assert_true(_has_button(&"action", JOY_BUTTON_Y), "Y is Action")
	assert_false(_has_button(&"action", JOY_BUTTON_A), "A no longer does Action")
	assert_false(_has_button(&"sprint", JOY_BUTTON_B), "B no longer sprints")
	assert_false(player.lock_on_enabled(), "GTA aims freely")
	assert_eq(player.controls.joypad_button_0_label.text, "Sprint", "The resting label follows the button")
	assert_eq(player.controls.joypad_button_3_label.text, "Action")
	assert_true(InputMap.action_get_events(&"sprint").any(func(e: InputEvent) -> bool: return e is InputEventKey), "The keyboard key stays on the action")


func test_switching_back_restores_zelda() -> void:
	player.control_scheme = preload("res://addons/gta/resources/control_schemes/gta.tres")
	player.control_scheme = preload("res://addons/3d_player_controller/resources/control_schemes/totk.tres")
	assert_true(_has_button(&"sprint", JOY_BUTTON_A))
	assert_false(_has_button(&"action", JOY_BUTTON_A))
	assert_true(_has_button(&"jump", JOY_BUTTON_Y))
	assert_eq(player.controls.joypad_button_0_label.text, "Sprint")


func test_focus_never_locks_on_under_gta() -> void:
	var target := StaticBody3D.new()
	target.add_to_group("Focusable")
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	target.add_child(shape)
	player.get_parent().add_child(target)
	target.global_position = player.global_position + Vector3(0.0, 1.0, -2.0)
	await wait_physics_frames(2)
	player.control_scheme = preload("res://addons/gta/resources/control_schemes/gta.tres")
	Input.action_press("focus")
	await wait_physics_frames(3)
	assert_null(player.current_focus_target, "Free aim acquires nobody")
	Input.action_release("focus")
	await wait_physics_frames(1)
	player.control_scheme = preload("res://addons/3d_player_controller/resources/control_schemes/totk.tres")
	Input.action_press("focus")
	await wait_physics_frames(3)
	assert_eq(player.current_focus_target, target, "Lock-on is back with Zelda")
	Input.action_release("focus")
	await wait_physics_frames(1)


func test_saved_setting_overrides_the_scene() -> void:
	# GTA ships with the gta addon, so a game offers it by registering it; nothing here preloads across addons
	PlayerControls.register_scheme(preload("res://addons/gta/resources/control_schemes/gta.tres"))
	var settings: PlayerSettingsResource = PlayerSettingsResource.load_or_create()
	settings.control_scheme_name = "GTA"
	settings.apply_control_scheme(player)
	assert_eq(player.control_scheme, preload("res://addons/gta/resources/control_schemes/gta.tres"))
	settings.control_scheme_name = ""
	player.control_scheme = preload("res://addons/3d_player_controller/resources/control_schemes/totk.tres")
	settings.apply_control_scheme(player)
	assert_eq(player.control_scheme, preload("res://addons/3d_player_controller/resources/control_schemes/totk.tres"), "Game Default leaves the scene's choice")


func test_the_video_settings_menu_lists_the_schemes() -> void:
	var menu: OptionButton = player.video_settings.get_node("Panel/VBoxContainer/ControlScheme")
	assert_eq(menu.item_count, 2, "The two layouts that ship here, and no redundant Default beside Zelda")
	assert_eq(menu.get_item_text(0), "Zelda")
	assert_eq(menu.get_item_text(1), "Platformer")
	assert_eq(menu.selected, 0, "Nothing saved, so it shows the layout the Player is actually using")

	player.video_settings._on_control_scheme_item_selected(1)
	assert_eq(player.control_scheme, preload("res://addons/3d_player_controller/resources/control_schemes/smo.tres"),
		"Picking one in the menu lays the pad out that way at once")
	assert_eq(player.controls.action_button_0, &"jump", "Jump is on the bottom button")

	# A layout another addon ships joins the list the moment it registers, without this menu knowing about it
	PlayerControls.register_scheme(preload("res://addons/gta/resources/control_schemes/gta.tres"))
	player.video_settings._fill_scheme_button()
	assert_eq(menu.item_count, 3, "and a registered layout is offered too")
	assert_eq(menu.get_item_text(2), "GTA")
	player.video_settings._on_control_scheme_item_selected(2)
	assert_eq(player.control_scheme, preload("res://addons/gta/resources/control_schemes/gta.tres"))


## The point of a scheme being a resource: a game ships its own layout without editing this addon. Built here in
## code rather than loaded from a .tres, because a game's file would not be in the addon to load.
func test_a_game_can_ship_a_layout_of_its_own() -> void:
	var southpaw := ControlScheme.new()
	southpaw.scheme_name = "Southpaw"
	southpaw.action_button_0 = &"attack"
	southpaw.action_button_1 = &"jump"
	southpaw.action_button_2 = &"action"
	southpaw.action_button_3 = &"sprint"
	southpaw.locks_on = false

	player.control_scheme = southpaw

	assert_true(_has_button(&"attack", JOY_BUTTON_A), "A is whatever the game's scheme says")
	assert_true(_has_button(&"jump", JOY_BUTTON_B))
	assert_true(_has_button(&"action", JOY_BUTTON_X))
	assert_true(_has_button(&"sprint", JOY_BUTTON_Y))
	assert_false(_has_button(&"action", JOY_BUTTON_A), "and A came off the action it used to carry")
	assert_false(player.lock_on_enabled(), "The scheme decides the aim too, not a name this addon knows")
	assert_eq(player.controls.joypad_button_0_label.text, "Attack", "The resting label follows")


## Whether Focus locks on is something a scheme carries rather than a comparison against the Zelda one, which is
## what it used to be. Super Mario Odyssey has no lock-on, so the Platformer layout does not either.
func test_the_scheme_carries_whether_focus_locks_on() -> void:
	player.control_scheme = preload("res://addons/3d_player_controller/resources/control_schemes/totk.tres")
	assert_true(player.lock_on_enabled(), "Zelda locks on")
	player.control_scheme = preload("res://addons/3d_player_controller/resources/control_schemes/smo.tres")
	assert_false(player.lock_on_enabled(), "Odyssey has no lock-on, so neither does Platformer")
	player.control_scheme = preload("res://addons/gta/resources/control_schemes/gta.tres")
	assert_false(player.lock_on_enabled())


## A settings file written before the pick was saved by name still means the layout it meant, and is rewritten
## as a name so it is only read once. Positions stopped being stable when an addon could register a layout.
func test_an_old_saved_index_becomes_the_name_it_stood_for() -> void:
	var settings: PlayerSettingsResource = PlayerSettingsResource.load_or_create()
	settings.control_scheme_name = ""
	PlayerControls.register_scheme(preload("res://addons/gta/resources/control_schemes/gta.tres"))
	settings.control_scheme_index = 2 # what "GTA" was saved as

	settings.apply_control_scheme(player)

	assert_eq(settings.control_scheme_name, "GTA", "The number is read as the name it stood for")
	assert_eq(settings.control_scheme_index, PlayerSettingsResource.GAME_DEFAULT, "and cleared, so it is never read again")
	assert_eq(player.control_scheme, preload("res://addons/gta/resources/control_schemes/gta.tres"))


## An addon ships a layout without the player controller preloading out of it, which it must not do: the
## template would then depend on an addon that may not be installed.
func test_a_registered_scheme_is_offered_and_saved_by_name() -> void:
	var southpaw := ControlScheme.new()
	southpaw.scheme_name = "Southpaw"
	southpaw.action_button_0 = &"attack"
	southpaw.action_button_1 = &"jump"
	southpaw.action_button_2 = &"action"
	southpaw.action_button_3 = &"sprint"

	PlayerControls.register_scheme(southpaw)
	PlayerControls.register_scheme(southpaw) # twice is once

	assert_true(PlayerControls.schemes().has(southpaw), "It joins what the menu offers")
	assert_eq(PlayerControls.schemes().count(southpaw), 1, "and only once")
	assert_eq(PlayerControls.scheme_named("Southpaw"), southpaw, "and answers to its name")

	var settings: PlayerSettingsResource = PlayerSettingsResource.load_or_create()
	settings.control_scheme_name = "Southpaw"
	settings.apply_control_scheme(player)
	assert_eq(player.control_scheme, southpaw, "so a saved pick finds it")
	assert_true(_has_button(&"attack", JOY_BUTTON_A), "and the pad is laid out its way")

	PlayerControls.forget_registered_schemes()
	settings.control_scheme_name = ""
	assert_null(PlayerControls.scheme_named("Southpaw"), "Forgotten, nothing answers to it")
