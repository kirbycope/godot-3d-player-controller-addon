extends GutTest

## Purpose: To test loading and saving user settings in PlayerSettingsResource at user://settings.tres
## without leaving the test values in the developer's real settings file.

var _backup: PackedByteArray
var _had_file: bool


func before_each() -> void:
	_had_file = FileAccess.file_exists(PlayerSettingsResource.SAVE_PATH)
	if _had_file:
		_backup = FileAccess.get_file_as_bytes(PlayerSettingsResource.SAVE_PATH)


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
