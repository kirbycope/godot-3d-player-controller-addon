extends CanvasLayer

@export var player: Player

@onready var panel: Panel = $Panel
@onready var dialog_slider: HSlider = panel.get_node("VBoxContainer/Dialog/VolumeSlider")
@onready var menu_slider: HSlider = panel.get_node("VBoxContainer/Menu/VolumeSlider")
@onready var music_slider: HSlider = panel.get_node("VBoxContainer/Music/VolumeSlider")
@onready var sfx_slider: HSlider = panel.get_node("VBoxContainer/SFX/VolumeSlider")
@onready var back: Button = panel.get_node("VBoxContainer/BACK")

var settings_res: PlayerSettingsResource


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(is_multiplayer_authority())
	set_physics_process(is_multiplayer_authority())
	set_process_input(is_multiplayer_authority())
	settings_res = PlayerSettingsResource.load_or_create()
	settings_res.apply_audio_settings(player)
	_init_volume_sliders()


func _init_volume_sliders() -> void:
	if settings_res:
		dialog_slider.value = settings_res.dialog_volume
		menu_slider.value = settings_res.menu_volume
		music_slider.value = settings_res.music_volume
		sfx_slider.value = settings_res.sfx_volume


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Close settings menu
	if event.is_action_pressed("start") \
	and visible:
		hide_settings()
		get_viewport().set_input_as_handled()


func show_settings() -> void:
	show()
	if player:
		player.is_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Panel/VBoxContainer/BACK.grab_focus()


func hide_settings() -> void:
	hide()
	if player:
		player.is_paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_bus_volume(bus_name: String, value: float) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		var volume_db = linear_to_db(value / 100.0) if value > 0 else -80.0
		AudioServer.set_bus_volume_db(bus_index, volume_db)


func _on_dialog_volume_slider_value_changed(value: float) -> void:
	_set_bus_volume("Dialog", value)
	if settings_res:
		settings_res.dialog_volume = value
		settings_res.save()


func _on_dialog_volume_minus_pressed() -> void:
	dialog_slider.value = max(dialog_slider.min_value, dialog_slider.value - 5.0)


func _on_dialog_volume_minus_touch_screen_button_pressed() -> void:
	_on_dialog_volume_minus_pressed()


func _on_dialog_volume_plus_pressed() -> void:
	dialog_slider.value = min(dialog_slider.max_value, dialog_slider.value + 5.0)


func _on_dialog_volume_plus_touch_screen_button_pressed() -> void:
	_on_dialog_volume_plus_pressed()


func _on_menu_volume_slider_value_changed(value: float) -> void:
	_set_bus_volume("Menu", value)
	if settings_res:
		settings_res.menu_volume = value
		settings_res.save()


func _on_menu_volume_minus_pressed() -> void:
	menu_slider.value = max(menu_slider.min_value, menu_slider.value - 5.0)


func _on_menu_volume_minus_touch_screen_button_pressed() -> void:
	_on_menu_volume_minus_pressed()


func _on_menu_volume_plus_pressed() -> void:
	menu_slider.value = min(menu_slider.max_value, menu_slider.value + 5.0)


func _on_menu_volume_plus_touch_screen_button_pressed() -> void:
	_on_menu_volume_plus_pressed()


func _on_music_volume_slider_value_changed(value: float) -> void:
	_set_bus_volume("Music", value)
	if player and player.has_method("update_music_volume"):
		player.update_music_volume(value)
	if settings_res:
		settings_res.music_volume = value
		settings_res.save()


func _on_music_volume_minus_pressed() -> void:
	music_slider.value = max(music_slider.min_value, music_slider.value - 5.0)


func _on_music_volume_minus_touch_screen_button_pressed() -> void:
	_on_music_volume_minus_pressed()


func _on_music_volume_plus_pressed() -> void:
	music_slider.value = min(music_slider.max_value, music_slider.value + 5.0)


func _on_music_volume_plus_touch_screen_button_pressed() -> void:
	_on_music_volume_plus_pressed()


func _on_sfx_volume_slider_value_changed(value: float) -> void:
	_set_bus_volume("SFX", value)
	if player and player.has_method("update_sfx_volume"):
		player.update_sfx_volume(value)
	if settings_res:
		settings_res.sfx_volume = value
		settings_res.save()


func _on_sfx_volume_minus_pressed() -> void:
	sfx_slider.value = max(sfx_slider.min_value, sfx_slider.value - 5.0)


func _on_sfx_volume_minus_touch_screen_button_pressed() -> void:
	_on_sfx_volume_minus_pressed()


func _on_sfx_volume_plus_pressed() -> void:
	sfx_slider.value = min(sfx_slider.max_value, sfx_slider.value + 5.0)


func _on_sfx_volume_plus_touch_screen_button_pressed() -> void:
	_on_sfx_volume_plus_pressed()


## Return to main settings menu.
func _on_back_pressed() -> void:
	hide()
	if player and player.settings:
		player.settings.show_settings()


func _on_back_touch_screen_button_pressed() -> void:
	_on_back_pressed()
