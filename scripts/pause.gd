extends CanvasLayer

@export var player: Player


## Called when there is an input event.
func _input(event: InputEvent) -> void:

	# Unpause
	if event.is_action_pressed("start") \
	and player.is_paused \
	and visible:
		hide_menu()
		get_viewport().set_input_as_handled()

	# Pause
	elif event.is_action_pressed("start") \
	and not player.is_paused \
	and not visible:
		show_menu()
		get_viewport().set_input_as_handled()


func show_menu() -> void:
	show()
	player.is_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Panel/VBoxContainer/Resume.grab_focus()


func hide_menu() -> void:
	hide()
	player.is_paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_resume_pressed() -> void:
	hide_menu()


func _on_resume_touch_screen_button_pressed() -> void:
	_on_resume_pressed()


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_restart_touch_screen_button_pressed() -> void:
	_on_restart_pressed()


func _on_settings_pressed() -> void:
	hide()
	player.settings.show_settings()


func _on_settings_touch_screen_button_pressed() -> void:
	_on_settings_pressed()


func _on_unstuck_pressed() -> void:
	if player:
		player.global_transform = player.initial_transform
		player.velocity = Vector3.ZERO
		player.up_direction = player.initial_transform.basis.y.normalized()
		player.orientation = Transform3D(player.initial_transform.basis, Vector3.ZERO)
		player.player_model.transform = player.initial_player_model_transform
		player.collision_shape.transform = player.initial_collision_shape_transform


func _on_unstuck_touch_screen_button_pressed() -> void:
	_on_unstuck_pressed()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_quit_touch_screen_button_pressed() -> void:
	_on_quit_pressed()
