extends PlayerMenuLayer

@onready var vsync_button: CheckButton = $Panel/VBoxContainer/VSYNC
@onready var ui_scale_button: OptionButton = $Panel/VBoxContainer/UIScale ## Items are [constant PlayerSettingsResource.UI_SCALES] in order.
@onready var hud_button: OptionButton = $Panel/VBoxContainer/OnScreenControls ## Items are [enum PlayerSettingsResource.HudMode] in order.
@onready var scheme_button: OptionButton = $Panel/VBoxContainer/ControlScheme ## Game Default, then [constant PlayerControls.BUILT_IN_SCHEMES] in order; filled by [method _fill_scheme_button].
@onready var toon_button: OptionButton = $Panel/VBoxContainer/ToonShading ## Items are [enum ToonFilter.Mode] in order.
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
	ui_scale_button.selected = clampi(settings_res.ui_scale_index, 0, ui_scale_button.item_count - 1)
	hud_button.selected = clampi(settings_res.hud_mode, 0, hud_button.item_count - 1)
	_fill_scheme_button()
	toon_button.selected = clampi(settings_res.toon_mode, 0, toon_button.item_count - 1)
	update_cel_availability(player.toon_filter.is_cel_available() if player and is_instance_valid(player.toon_filter) else RenderingServer.get_current_rendering_method() == ToonFilter.FORWARD_PLUS)
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


func _on_ui_scale_item_selected(index: int) -> void:
	settings_res.ui_scale_index = index
	_apply_and_save()


func _on_ui_scale_touch_screen_button_pressed() -> void:
	ui_scale_button.selected = (ui_scale_button.selected + 1) % ui_scale_button.item_count
	_on_ui_scale_item_selected(ui_scale_button.selected)


func _on_on_screen_controls_item_selected(index: int) -> void:
	settings_res.hud_mode = index
	if player:
		player.apply_hud_visibility()
	settings_res.save()


func _on_on_screen_controls_touch_screen_button_pressed() -> void:
	hud_button.selected = (hud_button.selected + 1) % hud_button.item_count
	_on_on_screen_controls_item_selected(hud_button.selected)


## The scheme goes straight on the Player, so the pad is laid out the new way as soon as the menu closes.
## Names the layouts from the scheme resources themselves rather than from items typed into the scene, so a
## game or another addon that registers a [ControlScheme] gets it listed without touching this menu. The pick
## is saved by name, so a layout registering late cannot change what an already saved choice means.
##
## There is no "Default" entry. It said the same thing as Zelda for anyone who had not changed it, which only
## made the menu harder to read; the layout a Player starts with is [constant PlayerControls.DEFAULT_SCHEME],
## and the menu simply shows whichever layout is on.
func _fill_scheme_button() -> void:
	settings_res.migrate_control_scheme() # a settings file written before the pick was saved by name
	scheme_button.clear()
	var wanted: String = settings_res.control_scheme_name
	if wanted.is_empty() and player and player.control_scheme:
		wanted = player.control_scheme.scheme_name # nothing saved: show what the Player is actually using
	var picked: int = 0
	var offered: Array[ControlScheme] = PlayerControls.schemes()
	for at: int in offered.size():
		scheme_button.add_item(offered[at].scheme_name, at)
		if offered[at].scheme_name == wanted:
			picked = at
	scheme_button.selected = picked


func _on_control_scheme_item_selected(index: int) -> void:
	var offered: Array[ControlScheme] = PlayerControls.schemes()
	settings_res.control_scheme_name = offered[index].scheme_name if index >= 0 and index < offered.size() else ""
	settings_res.control_scheme_index = PlayerSettingsResource.GAME_DEFAULT
	settings_res.apply_control_scheme(player)
	settings_res.save()


func _on_control_scheme_touch_screen_button_pressed() -> void:
	scheme_button.selected = (scheme_button.selected + 1) % scheme_button.item_count
	_on_control_scheme_item_selected(scheme_button.selected)


## Cel needs Forward+; elsewhere the option stays listed, greyed, with the reason as its tooltip.
func update_cel_availability(available: bool) -> void:
	toon_button.set_item_disabled(ToonFilter.Mode.CEL, not available)
	toon_button.set_item_tooltip(ToonFilter.Mode.CEL, "" if available else "Cel shading needs the Forward+ renderer")


## The option drives the Player's [ToonFilter] and saves the choice with the rest.
func _on_toon_shading_item_selected(index: int) -> void:
	settings_res.toon_mode = index
	_apply_and_save()
	if player and is_instance_valid(player.toon_filter):
		player.toon_filter.set_mode(index as ToonFilter.Mode)


## Steps to the next option, skipping a greyed Cel.
func _on_toon_shading_touch_screen_button_pressed() -> void:
	var next: int = (toon_button.selected + 1) % toon_button.item_count
	if toon_button.is_item_disabled(next):
		next = (next + 1) % toon_button.item_count
	toon_button.selected = next
	_on_toon_shading_item_selected(next)


## Wired to the ToonFilter's mode_changed: the [F6] key keeps the option honest.
func _on_toon_filter_mode_changed(mode: int) -> void:
	if is_node_ready():
		toon_button.selected = mode


## Wired to the ToonFilter's toggled in older Player scenes; reads the mode off the filter.
func _on_toon_filter_toggled(_enabled: bool) -> void:
	if player and is_instance_valid(player.toon_filter):
		_on_toon_filter_mode_changed(player.toon_filter.mode)


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
