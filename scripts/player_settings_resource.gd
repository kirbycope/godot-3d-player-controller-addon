class_name PlayerSettingsResource
extends Resource

const SAVE_PATH = "user://settings.tres"

# Audio Settings
@export var dialog_volume: float = 50.0
@export var menu_volume: float = 50.0
@export var music_volume: float = 50.0
@export var sfx_volume: float = 50.0

# Video Settings
@export var vsync_enabled: bool = true
@export var msaa_index: int = 0
@export var ssaa_index: int = 0
@export var fxaa_enabled: bool = false
@export var ssrl_enabled: bool = false
@export var taa_enabled: bool = false
@export var fsr_index: int = 0


static func load_or_create() -> PlayerSettingsResource:
	if ResourceLoader.exists(SAVE_PATH):
		var res = ResourceLoader.load(SAVE_PATH)
		if res is PlayerSettingsResource:
			return res
	return PlayerSettingsResource.new()


func save() -> void:
	ResourceSaver.save(self, SAVE_PATH)


func apply_audio_settings() -> void:
	_set_bus_volume("Dialog", dialog_volume)
	_set_bus_volume("Menu", menu_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)


func _set_bus_volume(bus_name: String, value: float) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		var volume_db = linear_to_db(value / 100.0) if value > 0 else -80.0
		AudioServer.set_bus_volume_db(bus_index, volume_db)


func apply_video_settings(viewport: Viewport) -> void:
	# VSYNC
	if vsync_enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	# MSAA
	var msaa_values = [
		RenderingServer.VIEWPORT_MSAA_DISABLED,
		RenderingServer.VIEWPORT_MSAA_2X,
		RenderingServer.VIEWPORT_MSAA_4X,
		RenderingServer.VIEWPORT_MSAA_8X,
	]
	if msaa_index >= 0 and msaa_index < msaa_values.size():
		viewport.set_msaa_3d(msaa_values[msaa_index])

	# SSAA
	var scale_factors = [1.0, 1.5, 2.0]
	if ssaa_index >= 0 and ssaa_index < scale_factors.size():
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = scale_factors[ssaa_index]

	# FXAA
	if fxaa_enabled:
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	else:
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED

	# SSRL
	RenderingServer.screen_space_roughness_limiter_set_active(ssrl_enabled, 0.25, 0.18)

	# TAA
	viewport.use_taa = taa_enabled

	# FSR
	viewport.scaling_3d_mode = fsr_index


func apply_all(viewport: Viewport) -> void:
	apply_audio_settings()
	if viewport:
		apply_video_settings(viewport)
