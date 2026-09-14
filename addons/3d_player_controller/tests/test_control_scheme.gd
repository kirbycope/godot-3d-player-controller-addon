extends GutTest

## Purpose: The Player answers to one of two pad layouts. Zelda is the scene's own: A is Action, B Sprint,
## X Attack, Y Jump, and Focus locks on. GTA moves the face buttons about (A Sprint, B Attack, X Jump,
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
	# The InputMap outlives the scene: put the pad back the way the other suites expect it
	if is_instance_valid(player):
		player.control_scheme = PlayerControls.ControlScheme.ZELDA
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
	assert_eq(player.control_scheme, PlayerControls.ControlScheme.ZELDA)
	assert_true(_has_button(&"action", JOY_BUTTON_A), "A is Action")
	assert_true(_has_button(&"sprint", JOY_BUTTON_B), "B is Sprint")
	assert_true(_has_button(&"attack", JOY_BUTTON_X), "X is Attack")
	assert_true(_has_button(&"jump", JOY_BUTTON_Y), "Y is Jump")
	assert_true(player.lock_on_enabled(), "Zelda locks on")
	assert_eq(player.controls.joypad_button_0_label.text, "Action")


func test_gta_moves_the_face_buttons_and_frees_the_aim() -> void:
	player.control_scheme = PlayerControls.ControlScheme.GTA
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
	player.control_scheme = PlayerControls.ControlScheme.GTA
	player.control_scheme = PlayerControls.ControlScheme.ZELDA
	assert_true(_has_button(&"action", JOY_BUTTON_A))
	assert_false(_has_button(&"sprint", JOY_BUTTON_A))
	assert_true(_has_button(&"jump", JOY_BUTTON_Y))
	assert_eq(player.controls.joypad_button_0_label.text, "Action")


func test_focus_never_locks_on_under_gta() -> void:
	var target := StaticBody3D.new()
	target.add_to_group("Focusable")
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	target.add_child(shape)
	player.get_parent().add_child(target)
	target.global_position = player.global_position + Vector3(0.0, 1.0, -2.0)
	await wait_physics_frames(2)
	player.control_scheme = PlayerControls.ControlScheme.GTA
	Input.action_press("focus")
	await wait_physics_frames(3)
	assert_null(player.current_focus_target, "Free aim acquires nobody")
	Input.action_release("focus")
	await wait_physics_frames(1)
	player.control_scheme = PlayerControls.ControlScheme.ZELDA
	Input.action_press("focus")
	await wait_physics_frames(3)
	assert_eq(player.current_focus_target, target, "Lock-on is back with Zelda")
	Input.action_release("focus")
	await wait_physics_frames(1)


func test_saved_setting_overrides_the_scene() -> void:
	var settings: PlayerSettingsResource = PlayerSettingsResource.load_or_create()
	settings.control_scheme_index = PlayerSettingsResource.SchemeSetting.GTA
	settings.apply_control_scheme(player)
	assert_eq(player.control_scheme, PlayerControls.ControlScheme.GTA)
	settings.control_scheme_index = PlayerSettingsResource.SchemeSetting.GAME_DEFAULT
	player.control_scheme = PlayerControls.ControlScheme.ZELDA
	settings.apply_control_scheme(player)
	assert_eq(player.control_scheme, PlayerControls.ControlScheme.ZELDA, "Game Default leaves the scene's choice")


func test_the_video_settings_menu_lists_the_schemes() -> void:
	var menu: OptionButton = player.video_settings.get_node("Panel/VBoxContainer/ControlScheme")
	assert_eq(menu.item_count, 3)
	assert_eq(menu.get_item_text(1), "Zelda")
	assert_eq(menu.get_item_text(2), "GTA")
	player.video_settings._on_control_scheme_item_selected(2)
	assert_eq(player.control_scheme, PlayerControls.ControlScheme.GTA, "Picking GTA in the menu lays the pad out that way at once")
