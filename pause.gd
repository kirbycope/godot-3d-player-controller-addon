extends CanvasLayer

@export var player: Player


## Called when the node enters the scene tree for the first time.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Unpause
	if event.is_action_pressed("start") \
	and player.is_paused \
	and visible:
		hide()
		player.is_paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()

	# Pause
	elif event.is_action_pressed("start") \
	and not player.is_paused \
	and not visible:
		show()
		player.is_paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_quit_touch_screen_button_pressed() -> void:
	_on_quit_pressed()


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_restart_touch_screen_button_pressed() -> void:
	_on_restart_pressed()


func _on_settings_pressed() -> void:
	hide()
	player.settings.show()


func _on_settings_touch_screen_button_pressed() -> void:
	_on_settings_pressed()


func _on_unstuck_touch_screen_button_pressed() -> void:
	_on_unstuck_pressed()


func _on_unstuck_pressed() -> void:
	player.global_position = player.initial_position
