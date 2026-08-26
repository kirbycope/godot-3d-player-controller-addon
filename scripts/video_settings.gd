extends CanvasLayer

@export var player: Player

@onready var panel: Panel = $Panel
@onready var vsync_button: CheckButton = panel.get_node("VBoxContainer/VSYNC")
@onready var msaa_button: OptionButton = panel.get_node("VBoxContainer/MSAA")
@onready var ssaa_button: OptionButton = panel.get_node("VBoxContainer/SSAA")
@onready var fxaa_button: CheckButton = panel.get_node("VBoxContainer/FXAA")
@onready var ssrl_button: CheckButton = panel.get_node("VBoxContainer/SSRL")
@onready var taa_button: CheckButton = panel.get_node("VBoxContainer/TAA")
@onready var fsr_button: OptionButton = panel.get_node("VBoxContainer/FSR")
@onready var back: Button = panel.get_node("VBoxContainer/BACK")

@onready var project_rendering_method = ProjectSettings.get_setting("rendering/renderer/rendering_method")

var settings_res: PlayerSettingsResource


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(is_multiplayer_authority())
	set_physics_process(is_multiplayer_authority())
	set_process_input(is_multiplayer_authority())

	settings_res = PlayerSettingsResource.load_or_create()
	settings_res.apply_video_settings(get_viewport())

	# By default, hide anything not for all renderers
	fxaa_button.visible = false
	ssrl_button.visible = false
	taa_button.visible = false
	fsr_button.visible = false

	# Vsync - This is available in all renderers.
	vsync_button.button_pressed = settings_res.vsync_enabled
	# Multisample antialiasing (MSAA) - This is available in all renderers.
	msaa_button.selected = settings_res.msaa_index
	# Supersample antialiasing (SSAA) - This is available in all renderers.
	ssaa_button.selected = settings_res.ssaa_index

	# Check if the rendering method is "Forward+" or "Mobile"
	if project_rendering_method == "forward_plus" or project_rendering_method == "mobile":
		# Fast approximate antialiasing (FXAA)
		fxaa_button.visible = true
		fxaa_button.button_pressed = settings_res.fxaa_enabled
		# Screen-space roughness limiter
		ssrl_button.visible = true
		ssrl_button.button_pressed = settings_res.ssrl_enabled

	# Check if the rendering method is "Forward+"
	if project_rendering_method == "forward_plus":
		# Temporal antialiasing (TAA)
		taa_button.visible = true
		taa_button.button_pressed = settings_res.taa_enabled
		# AMD FidelityFX Super Resolution 2.2 (FSR2)
		fsr_button.visible = true
		fsr_button.selected = settings_res.fsr_index


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Close settings menu
	if event.is_action_pressed("start") \
	and visible:
		hide_settings()
		get_viewport().set_input_as_handled()


func show_settings() -> void:
	show()
	player.is_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Panel/VBoxContainer/BACK.grab_focus()


func hide_settings() -> void:
	hide()
	player.is_paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Change the VSYNC value.
func _on_vsync_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	if settings_res:
		settings_res.vsync_enabled = toggled_on
		settings_res.save()


func _on_vsync_touch_screen_button_pressed() -> void:
	_on_vsync_toggled(not vsync_button.button_pressed)


## Change the MSAA value.
func _on_msaa_item_selected(index: int) -> void:
	var msaa_values = [
		RenderingServer.VIEWPORT_MSAA_DISABLED,
		RenderingServer.VIEWPORT_MSAA_2X,
		RenderingServer.VIEWPORT_MSAA_4X,
		RenderingServer.VIEWPORT_MSAA_8X,
	]
	get_viewport().set_msaa_3d(msaa_values[index])

	if settings_res:
		settings_res.msaa_index = index
		settings_res.save()


func _on_msaa_touch_screen_button_pressed() -> void:
	var option = msaa_button.selected + 1
	if option > 3:
		option = 0
	_on_msaa_item_selected(option)


## Change the SSAA value.
func _on_ssaa_item_selected(index: int) -> void:
	var scale_factors = [1.0, 1.5, 2.0]
	var viewport = get_viewport()
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = scale_factors[index]

	if settings_res:
		settings_res.ssaa_index = index
		settings_res.save()


func _on_ssaa_touch_screen_button_pressed() -> void:
	var option = ssaa_button.selected + 1
	if option > 2:
		option = 0
	_on_ssaa_item_selected(option)


## Change the FXAA value.
func _on_fxaa_toggled(toggled_on: bool) -> void:
	var viewport = get_viewport()
	if toggled_on:
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	else:
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED

	if settings_res:
		settings_res.fxaa_enabled = toggled_on
		settings_res.save()


func _on_fxaa_touch_screen_button_pressed() -> void:
	_on_fxaa_toggled(not fxaa_button.button_pressed)


## Change the SSRL value.
func _on_ssrl_toggled(toggled_on: bool) -> void:
	RenderingServer.screen_space_roughness_limiter_set_active(toggled_on, 0.25, 0.18)

	if settings_res:
		settings_res.ssrl_enabled = toggled_on
		settings_res.save()


func _on_ssrl_touch_screen_button_pressed() -> void:
	_on_ssrl_toggled(not ssrl_button.button_pressed)


## Change the TAA value.
func _on_taa_toggled(toggled_on: bool) -> void:
	var viewport = get_viewport()
	viewport.use_taa = toggled_on

	if settings_res:
		settings_res.taa_enabled = toggled_on
		settings_res.save()


func _on_taa_touch_screen_button_pressed() -> void:
	_on_taa_toggled(not taa_button.button_pressed)


## Change the FSR value.
func _on_fsr_item_selected(index: int) -> void:
	var viewport = get_viewport()
	viewport.scaling_3d_mode = index

	if settings_res:
		settings_res.fsr_index = index
		settings_res.save()


func _on_fsr_touch_screen_button_pressed() -> void:
	_on_fsr_item_selected(not fsr_button.button_pressed)


## Return to main settings menu.
func _on_back_pressed() -> void:
	hide()
	if player and player.settings:
		player.settings.show_settings()


func _on_back_touch_screen_button_pressed() -> void:
	_on_back_pressed()
