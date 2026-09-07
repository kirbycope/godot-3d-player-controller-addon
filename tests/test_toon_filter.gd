extends IntegrationTestBase

## Purpose: the ToonFilter's shader compiles, the filter starts off, toggles from the Video settings switch, the
## toggle_toon action and its [F6] key, saves the choice with the other video settings in user://settings.tres
## (backed up and restored here), and is drawn in the 3D pass under the Player's camera so every CanvasLayer (the
## HUD) sits above it.

const TOON_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/toon_filter.tscn")
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")

var _backup: PackedByteArray
var _had_file: bool


func before_each() -> void:
	_had_file = FileAccess.file_exists(PlayerSettingsResource.SAVE_PATH)
	if _had_file:
		_backup = FileAccess.get_file_as_bytes(PlayerSettingsResource.SAVE_PATH)
	DirAccess.remove_absolute(PlayerSettingsResource.SAVE_PATH)
	PlayerSettingsResource._cached = null


func after_each() -> void:
	if _had_file:
		var file: FileAccess = FileAccess.open(PlayerSettingsResource.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(_backup)
		file.close()
		ResourceLoader.load(PlayerSettingsResource.SAVE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	else:
		DirAccess.remove_absolute(PlayerSettingsResource.SAVE_PATH)
	PlayerSettingsResource._cached = null


func _saved_toon() -> bool:
	var loaded: PlayerSettingsResource = ResourceLoader.load(PlayerSettingsResource.SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	return loaded.toon_enabled


func test_the_shader_compiles_with_its_dials() -> void:
	var filter: ToonFilter = TOON_SCENE.instantiate()
	add_child_autofree(filter)
	var material: ShaderMaterial = filter.mesh.surface_get_material(0)
	var names: Array[String] = []
	for parameter: Dictionary in RenderingServer.get_shader_parameter_list(material.shader.get_rid()):
		names.append(parameter.name)
	# A shader that failed to compile lists no uniforms at all
	for uniform: String in ["bands", "softness", "outline_color", "outline_threshold", "outline_thickness", "strength"]:
		assert_has(names, uniform, "The toon shader compiled and exposes " + uniform)
	assert_eq(material.render_priority, Material.RENDER_PRIORITY_MIN, "Drawn first among the transparents, so water and VFX draw over it")
	assert_false(filter.visible, "Off by default")
	assert_false(filter.enabled)


func test_toggle_shows_the_filter_and_saves_the_choice() -> void:
	var filter: ToonFilter = TOON_SCENE.instantiate()
	add_child_autofree(filter)
	watch_signals(filter)
	filter.toggle()
	assert_true(filter.enabled)
	assert_true(filter.visible, "Enabled shows the quad")
	assert_signal_emitted_with_parameters(filter, "toggled", [true])
	assert_true(_saved_toon(), "The choice is saved with the other video settings")
	var second: ToonFilter = TOON_SCENE.instantiate()
	add_child_autofree(second)
	assert_true(second.enabled, "A new filter starts from the saved setting")
	filter.toggle()
	assert_false(filter.visible)
	assert_false(_saved_toon())


func test_the_switch_and_the_key_drive_the_players_filter_under_the_hud() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var player: Player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await wait_physics_frames(2)
	var filter: ToonFilter = player.toon_filter
	assert_eq(filter.get_parent(), player.camera, "Under the camera, so only the current camera draws it")
	assert_true(filter is VisualInstance3D, "Drawn in the 3D pass, before every CanvasLayer, so the HUD sits above it")
	assert_true(player.controls is CanvasLayer, "The HUD is a CanvasLayer")
	assert_true(InputMap.has_action("toggle_toon"), "Controls registers the action")
	assert_true(InputMap.action_has_event("toggle_toon", _f6()), "Bound to F6")
	assert_false(filter.enabled, "Off until asked")
	var video: PlayerMenuLayer = player.video_settings
	video._on_toon_shading_toggled(true)
	assert_true(filter.enabled, "The Video settings switch turns it on")
	assert_true(_saved_toon())
	await send_key(KEY_F6)
	assert_false(filter.enabled, "F6 turns it off again")
	assert_false(video.toon_button.button_pressed, "The switch follows the key")
	assert_false(_saved_toon(), "And the key's choice is saved too")


func _f6() -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_F6
	return key
