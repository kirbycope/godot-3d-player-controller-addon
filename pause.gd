extends CanvasLayer

@export var player: Player


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


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_settings_pressed() -> void:
	hide()
	player.settings.show()


func _on_unstuck_pressed() -> void:
	player.global_position = player.initial_position
