extends CanvasLayer

@export var player: Player

@onready var panel: Panel = $Panel
@onready var label: Label = panel.get_node("VBoxContainer/Panel/Label")
@onready var info_label: Label = panel.get_node("VBoxContainer/InfoLabel")
@onready var invite_button: Button = panel.get_node("VBoxContainer/Invite")
@onready var leave_button: Button = panel.get_node("VBoxContainer/Leave")
@onready var back_button: Button = panel.get_node("VBoxContainer/BACK")


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(is_multiplayer_authority())
	set_physics_process(is_multiplayer_authority())
	set_process_input(is_multiplayer_authority())


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Close lobby menu and return to pause
	if event.is_action_pressed("start") and visible:
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func show_menu() -> void:
	show()
	if player:
		player.is_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_lobby_ui()
	if invite_button and not invite_button.disabled:
		invite_button.grab_focus()
	elif back_button:
		back_button.grab_focus()


func hide_menu() -> void:
	hide()
	if player:
		player.is_paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _update_lobby_ui() -> void:
	if not Engine.has_singleton("Steam") or not Steam.isSteamRunning():
		info_label.text = "Steam unavailable"
		invite_button.disabled = true
		leave_button.disabled = true
		return

	var steamworks = get_node_or_null("/root/Steamworks")
	var active_lobby_id: int = steamworks.lobby_id if steamworks else 0

	if active_lobby_id > 0:
		var owner_id: int = Steam.getLobbyOwner(active_lobby_id)
		var owner_name: String = Steam.getFriendPersonaName(owner_id)
		var member_count: int = Steam.getNumLobbyMembers(active_lobby_id)
		info_label.text = "Host: %s\nPlayers: %d/4" % [owner_name, member_count]
		invite_button.disabled = false
		leave_button.disabled = false
	else:
		info_label.text = "No active lobby"
		invite_button.disabled = true
		leave_button.disabled = true


func _on_invite_pressed() -> void:
	var steamworks = get_node_or_null("/root/Steamworks")
	var active_lobby_id: int = steamworks.lobby_id if steamworks else 0
	if Engine.has_singleton("Steam") and active_lobby_id > 0:
		Steam.activateGameOverlayInviteDialog(active_lobby_id)


func _on_invite_touch_screen_button_pressed() -> void:
	_on_invite_pressed()


func _on_leave_pressed() -> void:
	var steamworks = get_node_or_null("/root/Steamworks")
	var active_lobby_id: int = steamworks.lobby_id if steamworks else 0
	if Engine.has_singleton("Steam") and active_lobby_id > 0:
		Steam.leaveLobby(active_lobby_id)
		if steamworks:
			steamworks.lobby_id = 0
		_update_lobby_ui()


func _on_leave_touch_screen_button_pressed() -> void:
	_on_leave_pressed()


## Return to the pause menu.
func _on_back_pressed() -> void:
	hide()
	if player and player.pause:
		player.pause.show_menu()


func _on_back_touch_screen_button_pressed() -> void:
	_on_back_pressed()
