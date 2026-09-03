extends PlayerMenuLayer

@onready var vsync_button: CheckButton = $Panel/VBoxContainer/VSYNC
@onready var msaa_button: OptionButton = $Panel/VBoxContainer/MSAA
@onready var ssaa_button: OptionButton = $Panel/VBoxContainer/SSAA
@onready var fxaa_button: CheckButton = $Panel/VBoxContainer/FXAA
@onready var ssrl_button: CheckButton = $Panel/VBoxContainer/SSRL
@onready var taa_button: CheckButton = $Panel/VBoxContainer/TAA
@onready var fsr_button: OptionButton = $Panel/VBoxContainer/FSR

var settings_res: PlayerSettingsResource


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	settings_res = PlayerSettingsResource.load_or_create()
	var rendering_method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	var is_forward_plus: bool = rendering_method == "forward_plus"
	var is_forward_plus_or_mobile: bool = is_forward_plus or rendering_method == "mobile"

	# Available in all renderers
	vsync_button.set_pressed_no_signal(settings_res.vsync_enabled)
	msaa_button.selected = settings_res.msaa_index
	ssaa_button.selected = settings_res.ssaa_index
	# Forward+ and Mobile only
	fxaa_button.visible = is_forward_plus_or_mobile
	fxaa_button.set_pressed_no_signal(settings_res.fxaa_enabled)
	ssrl_button.visible = is_forward_plus_or_mobile
	ssrl_button.set_pressed_no_signal(settings_res.ssrl_enabled)
	# Forward+ only
	taa_button.visible = is_forward_plus
	taa_button.set_pressed_no_signal(settings_res.taa_enabled)
	fsr_button.visible = is_forward_plus
	fsr_button.selected = settings_res.fsr_index


## Applies the whole resource to the viewport (the resource owns the value tables) and persists it.
func _apply_and_save() -> void:
	settings_res.apply_video_settings(get_viewport())
	settings_res.save()


func _on_vsync_toggled(toggled_on: bool) -> void:
	settings_res.vsync_enabled = toggled_on
	_apply_and_save()


func _on_vsync_touch_screen_button_pressed() -> void:
	_on_vsync_toggled(not vsync_button.button_pressed)


func _on_msaa_item_selected(index: int) -> void:
	settings_res.msaa_index = index
	_apply_and_save()


func _on_msaa_touch_screen_button_pressed() -> void:
	msaa_button.selected = (msaa_button.selected + 1) % msaa_button.item_count
	_on_msaa_item_selected(msaa_button.selected)


## SSAA and FSR share the viewport's 3D scaling, so picking one resets the other.
func _on_ssaa_item_selected(index: int) -> void:
	settings_res.ssaa_index = index
	if index > 0:
		settings_res.fsr_index = 0
		fsr_button.selected = 0
	_apply_and_save()


func _on_ssaa_touch_screen_button_pressed() -> void:
	ssaa_button.selected = (ssaa_button.selected + 1) % ssaa_button.item_count
	_on_ssaa_item_selected(ssaa_button.selected)


func _on_fxaa_toggled(toggled_on: bool) -> void:
	settings_res.fxaa_enabled = toggled_on
	_apply_and_save()


func _on_fxaa_touch_screen_button_pressed() -> void:
	_on_fxaa_toggled(not fxaa_button.button_pressed)


func _on_ssrl_toggled(toggled_on: bool) -> void:
	settings_res.ssrl_enabled = toggled_on
	_apply_and_save()


func _on_ssrl_touch_screen_button_pressed() -> void:
	_on_ssrl_toggled(not ssrl_button.button_pressed)


func _on_taa_toggled(toggled_on: bool) -> void:
	settings_res.taa_enabled = toggled_on
	_apply_and_save()


func _on_taa_touch_screen_button_pressed() -> void:
	_on_taa_toggled(not taa_button.button_pressed)


## FSR and SSAA share the viewport's 3D scaling, so picking one resets the other.
func _on_fsr_item_selected(index: int) -> void:
	settings_res.fsr_index = index
	if index > 0:
		settings_res.ssaa_index = 0
		ssaa_button.selected = 0
	_apply_and_save()


func _on_fsr_touch_screen_button_pressed() -> void:
	fsr_button.selected = (fsr_button.selected + 1) % fsr_button.item_count
	_on_fsr_item_selected(fsr_button.selected)


## Return to main settings menu.
func _on_back_pressed() -> void:
	if player == null:
		return
	hide()
	player.settings.show_menu()


func _on_back_touch_screen_button_pressed() -> void:
	_on_back_pressed()
