extends PlayerMenuLayer

@onready var dialog_slider: HSlider = $Panel/VBoxContainer/Dialog/VolumeSlider
@onready var menu_slider: HSlider = $Panel/VBoxContainer/Menu/VolumeSlider
@onready var music_slider: HSlider = $Panel/VBoxContainer/Music/VolumeSlider
@onready var sfx_slider: HSlider = $Panel/VBoxContainer/SFX/VolumeSlider
@onready var voice_settings: VBoxContainer = $Panel/VBoxContainer/VoiceSettings ## Steam voice chat rows; shown only when Steam is loaded.
@onready var voice_slider: HSlider = $Panel/VBoxContainer/VoiceSettings/Voice/VolumeSlider
@onready var mute_voice: CheckButton = $Panel/VBoxContainer/VoiceSettings/MuteVoice
@onready var microphone_label: Label = $Panel/VBoxContainer/VoiceSettings/Microphone
@onready var mic_sensitivity: VoiceLevelSlider = $Panel/VBoxContainer/VoiceSettings/Microphone/Sensitivity ## Both the microphone meter and the setting; one bar, after PulseAudio's.

var settings_res: PlayerSettingsResource


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	settings_res = PlayerSettingsResource.load_or_create()
	dialog_slider.set_value_no_signal(settings_res.dialog_volume)
	menu_slider.set_value_no_signal(settings_res.menu_volume)
	music_slider.set_value_no_signal(settings_res.music_volume)
	sfx_slider.set_value_no_signal(settings_res.sfx_volume)
	voice_slider.set_value_no_signal(settings_res.voice_volume)
	mute_voice.set_pressed_no_signal(settings_res.voice_muted)
	mic_sensitivity.set_value_no_signal(settings_res.voice_sensitivity)
	var hint: String = microphone_hint()
	mic_sensitivity.tooltip_text = hint
	microphone_label.tooltip_text = hint
	microphone_label.text = microphone_label_text()
	mic_sensitivity.value_changed.connect(_on_mic_sensitivity_changed)
	voice_settings.visible = is_steam_loaded()
	set_process(true)


## What push-to-talk is bound to, as a key name, or empty when nothing is. Read off the [InputMap] rather than
## written into a string, so it follows a rebind and cannot quietly go stale: the action is [code]broadcast[/code],
## which this addon's controls register on V, and it sits on no controller slot, so there is no pad button to name.
func talk_key_name() -> String:
	if not InputMap.has_action(&"broadcast"):
		return ""
	for event: InputEvent in InputMap.action_get_events(&"broadcast"):
		if event is InputEventKey:
			var key: InputEventKey = event
			return OS.get_keycode_string(key.physical_keycode if key.physical_keycode != 0 else key.keycode)
	return ""


## The row's own label, naming the key so the instruction is visible without hunting for a tooltip.
func microphone_label_text() -> String:
	var key: String = talk_key_name()
	return "Microphone" if key.is_empty() else "Microphone (hold %s)" % key


## The tip on the row: what the bar is, and what to do to set it.
func microphone_hint() -> String:
	var key: String = talk_key_name()
	var press: String = "push-to-talk" if key.is_empty() else key
	return ("Hold %s and speak. The bar fills with what your microphone hears; drag the handle so an ordinary "
			+ "voice reaches the mark.") % press


## The bar shows what the microphone is hearing right now, so the handle can be set by talking rather than by
## guessing. Only while the menu is open, and only for the Player whose settings these are.
func _process(_delta: float) -> void:
	if not visible or player == null:
		return
	mic_sensitivity.level = player.voice_loudness


## Saved as it moves; a drag ends wherever the player lets go and there is no separate confirm.
func _on_mic_sensitivity_changed(value: float) -> void:
	settings_res.voice_sensitivity = value
	settings_res.save()


## Voice chat runs on Steam only, so its rows show only with the Steam singleton; a test overrides this to see both layouts.
func is_steam_loaded() -> bool:
	return Engine.has_singleton("Steam")


## Mutes or unmutes the Voice bus on this machine only and saves at once (a toggle has no drag to end).
func _on_mute_voice_toggled(toggled_on: bool) -> void:
	settings_res.voice_muted = toggled_on
	PlayerSettingsResource.set_bus_mute(&"Voice", toggled_on)
	settings_res.save()


func _on_mute_voice_touch_screen_button_pressed() -> void:
	mute_voice.button_pressed = not mute_voice.button_pressed # Emits toggled


## Applies a slider value to its bus (bound in the scene) without saving.
func _on_volume_slider_value_changed(value: float, bus: StringName) -> void:
	PlayerSettingsResource.set_bus_volume(bus, value)
	settings_res.set(bus.to_lower() + "_volume", value) # dialog_volume, menu_volume, music_volume, sfx_volume
	if player and bus == &"Music":
		player.update_music_volume(value)
	elif player and bus == &"SFX":
		player.update_sfx_volume(value)


## Saves once the slider is released instead of on every value tick.
func _on_volume_slider_drag_ended(_value_changed: bool) -> void:
	settings_res.save()


## Steps a slider (bound in the scene) down by 5; the slider clamps and emits value_changed.
func _on_volume_minus_pressed(slider: NodePath) -> void:
	(get_node(slider) as HSlider).value -= 5.0


## Steps a slider (bound in the scene) up by 5; the slider clamps and emits value_changed.
func _on_volume_plus_pressed(slider: NodePath) -> void:
	(get_node(slider) as HSlider).value += 5.0


## Saves when the menu closes by any route (BACK button or "start").
func _on_visibility_changed() -> void:
	if not visible and settings_res:
		settings_res.save()


func _on_dialog_volume_minus_touch_screen_button_pressed() -> void:
	_on_volume_minus_pressed(dialog_slider.get_path())


func _on_dialog_volume_plus_touch_screen_button_pressed() -> void:
	_on_volume_plus_pressed(dialog_slider.get_path())


func _on_menu_volume_minus_touch_screen_button_pressed() -> void:
	_on_volume_minus_pressed(menu_slider.get_path())


func _on_menu_volume_plus_touch_screen_button_pressed() -> void:
	_on_volume_plus_pressed(menu_slider.get_path())


func _on_music_volume_minus_touch_screen_button_pressed() -> void:
	_on_volume_minus_pressed(music_slider.get_path())


func _on_music_volume_plus_touch_screen_button_pressed() -> void:
	_on_volume_plus_pressed(music_slider.get_path())


func _on_sfx_volume_minus_touch_screen_button_pressed() -> void:
	_on_volume_minus_pressed(sfx_slider.get_path())


func _on_sfx_volume_plus_touch_screen_button_pressed() -> void:
	_on_volume_plus_pressed(sfx_slider.get_path())


func _on_voice_volume_minus_touch_screen_button_pressed() -> void:
	_on_volume_minus_pressed(voice_slider.get_path())


func _on_voice_volume_plus_touch_screen_button_pressed() -> void:
	_on_volume_plus_pressed(voice_slider.get_path())


## Return to main settings menu.
func _on_back_pressed() -> void:
	if player == null:
		return
	hide()
	player.settings.show_menu()


func _on_back_touch_screen_button_pressed() -> void:
	_on_back_pressed()
