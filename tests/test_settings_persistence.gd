extends GutTest

## Purpose: To test loading and saving user settings in PlayerSettingsResource at user://settings.tres.

class TestSettingsPersistence:
	extends GutTest

	func test_save_and_load_settings_resource():
		var settings = PlayerSettingsResource.new()
		settings.dialog_volume = 75.0
		settings.music_volume = 30.0
		settings.vsync_enabled = false
		settings.msaa_index = 2
		settings.save()

		assert_true(FileAccess.file_exists(PlayerSettingsResource.SAVE_PATH), "Save file user://settings.tres should exist")

		var loaded = PlayerSettingsResource.load_or_create()
		assert_not_null(loaded, "Loaded resource should not be null")
		assert_eq(loaded.dialog_volume, 75.0, "Dialog volume should persist")
		assert_eq(loaded.music_volume, 30.0, "Music volume should persist")
		assert_eq(loaded.vsync_enabled, false, "VSync enabled should persist")
		assert_eq(loaded.msaa_index, 2, "MSAA index should persist")
