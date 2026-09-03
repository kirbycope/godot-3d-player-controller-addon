extends GutTest

## Purpose: To test loading and saving user settings in PlayerSettingsResource at user://settings.tres
## without leaving the test values in the developer's real settings file.

const AUDIO_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/audio.tscn")
const AUDIO_SETTINGS_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/audio_settings.tscn")
const VIDEO_SETTINGS_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/video_settings.tscn")

var _backup: PackedByteArray
var _had_file: bool


func before_each() -> void:
	_had_file = FileAccess.file_exists(PlayerSettingsResource.SAVE_PATH)
	if _had_file:
		_backup = FileAccess.get_file_as_bytes(PlayerSettingsResource.SAVE_PATH)
	PlayerSettingsResource._cached = null


func after_each() -> void:
	if _had_file:
		var file: FileAccess = FileAccess.open(PlayerSettingsResource.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(_backup)
		file.close()
		ResourceLoader.load(PlayerSettingsResource.SAVE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	else:
		DirAccess.remove_absolute(PlayerSettingsResource.SAVE_PATH)
		if ResourceLoader.has_cached(PlayerSettingsResource.SAVE_PATH):
			var cached: PlayerSettingsResource = ResourceLoader.load(PlayerSettingsResource.SAVE_PATH)
			var defaults: PlayerSettingsResource = PlayerSettingsResource.new()
			for property: Dictionary in defaults.get_property_list():
				if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
					cached.set(property.name, defaults.get(property.name))
	PlayerSettingsResource._cached = null


func test_save_and_load_settings_resource() -> void:
	var settings: PlayerSettingsResource = PlayerSettingsResource.new()
	settings.dialog_volume = 75.0
	settings.music_volume = 30.0
	settings.vsync_enabled = false
	settings.msaa_index = 2
	settings.save()

	assert_true(FileAccess.file_exists(PlayerSettingsResource.SAVE_PATH), "Save file user://settings.tres should exist")

	var loaded: PlayerSettingsResource = PlayerSettingsResource.load_or_create()
	assert_eq(loaded.dialog_volume, 75.0, "Dialog volume should persist")
	assert_eq(loaded.music_volume, 30.0, "Music volume should persist")
	assert_eq(loaded.vsync_enabled, false, "VSync enabled should persist")
	assert_eq(loaded.msaa_index, 2, "MSAA index should persist")


func test_load_or_create_returns_one_shared_instance() -> void:
	assert_same(PlayerSettingsResource.load_or_create(), PlayerSettingsResource.load_or_create(), "Every menu should edit the same instance")


func test_menu_layer_show_hide_toggles_player_paused() -> void:
	var layer: PlayerMenuLayer = PlayerMenuLayer.new()
	add_child_autofree(layer)
	var player: Player = autofree(Player.new())
	layer.player = player

	layer.show_menu()
	assert_true(layer.visible, "show_menu should show the layer")
	assert_true(player.is_paused, "show_menu should pause the player")

	layer.hide_menu()
	assert_false(layer.visible, "hide_menu should hide the layer")
	assert_false(player.is_paused, "hide_menu should unpause the player")


func test_audio_slider_applies_bus_volume_and_saves_on_drag_ended() -> void:
	DirAccess.remove_absolute(PlayerSettingsResource.SAVE_PATH)
	add_child_autofree(AUDIO_SCENE.instantiate()) # Creates the buses
	var audio_settings: PlayerMenuLayer = AUDIO_SETTINGS_SCENE.instantiate() as PlayerMenuLayer
	add_child_autofree(audio_settings)

	audio_settings.menu_slider.value = 20.0
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Menu")), linear_to_db(0.2), 0.001, "value_changed should apply the bus volume")
	assert_eq(audio_settings.settings_res.menu_volume, 20.0, "value_changed should update the resource")
	assert_false(FileAccess.file_exists(PlayerSettingsResource.SAVE_PATH), "value_changed should not save to disk")

	audio_settings.menu_slider.drag_ended.emit(true)
	assert_true(FileAccess.file_exists(PlayerSettingsResource.SAVE_PATH), "drag_ended should save to disk")
	PlayerSettingsResource.set_bus_volume(&"Menu", 50.0)


func test_fsr_and_ssaa_are_mutually_exclusive_and_round_trip() -> void:
	var video_settings: PlayerMenuLayer = VIDEO_SETTINGS_SCENE.instantiate() as PlayerMenuLayer
	add_child_autofree(video_settings)

	video_settings._on_ssaa_item_selected(2)
	video_settings._on_fsr_item_selected(1)
	assert_eq(video_settings.settings_res.ssaa_index, 0, "Selecting FSR should reset SSAA")
	assert_eq(video_settings.ssaa_button.selected, 0, "Selecting FSR should reset the SSAA control")

	var loaded: PlayerSettingsResource = ResourceLoader.load(PlayerSettingsResource.SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(loaded.fsr_index, 1, "FSR index should persist")
	assert_eq(loaded.ssaa_index, 0, "SSAA index should persist as reset")

	video_settings._on_ssaa_item_selected(1)
	assert_eq(video_settings.settings_res.fsr_index, 0, "Selecting SSAA should reset FSR")
	assert_eq(video_settings.fsr_button.selected, 0, "Selecting SSAA should reset the FSR control")
	video_settings._on_ssaa_item_selected(0)
