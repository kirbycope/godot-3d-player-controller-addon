extends PlayerMenuLayer

@onready var lobby: Button = $Panel/VBoxContainer/Lobby


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	var rendering_method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	var lobby_unavailable: bool = rendering_method not in ["forward_plus", "mobile"] \
		or OS.has_feature("gl_compatibility") \
		or OS.has_feature("web") \
		or not Engine.has_singleton("Steam")
	lobby.disabled = lobby_unavailable


## Called when there is an input event; "start" toggles the pause menu.
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("start"):
		return
	if visible:
		hide_menu()
	elif player and not player.is_paused:
		show_menu()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_lobby_pressed() -> void:
	if player == null or lobby.disabled or player.lobby_manager == null:
		return
	hide()
	player.lobby_manager.show_menu()


func _on_lobby_touch_screen_button_pressed() -> void:
	_on_lobby_pressed()


func _on_resume_pressed() -> void:
	hide_menu()


func _on_resume_touch_screen_button_pressed() -> void:
	_on_resume_pressed()


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_restart_touch_screen_button_pressed() -> void:
	_on_restart_pressed()


func _on_settings_pressed() -> void:
	if player == null:
		return
	hide()
	player.settings.show_menu()


func _on_settings_touch_screen_button_pressed() -> void:
	_on_settings_pressed()


func _on_unstuck_pressed() -> void:
	if player == null:
		return
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
