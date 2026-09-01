extends CanvasLayer

@export var lobby_player_item_scene: PackedScene ## Assigned in the scene so it ships as a scene dependency.

@export var player: Player

## Steam singleton when the GodotSteam extension is present, otherwise null.
var _steam: Object = Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null

@onready var panel: Panel = $Panel
@onready var label: Label = panel.get_node("VBoxContainer/Panel/Label")
@onready var info_label: Label = panel.get_node("VBoxContainer/InfoLabel")
@onready var player_list: VBoxContainer = panel.get_node_or_null("VBoxContainer/ScrollContainer/PlayerList")
@onready var invite_button: Button = panel.get_node("VBoxContainer/HBoxContainer/Invite")
@onready var leave_button: Button = panel.get_node("VBoxContainer/HBoxContainer/Leave")
@onready var back_button: Button = panel.get_node("VBoxContainer/BACK")


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(is_multiplayer_authority())
	set_physics_process(is_multiplayer_authority())
	set_process_input(is_multiplayer_authority())
	_connect_steam_callbacks()


func _connect_steam_callbacks() -> void:
	if _steam == null:
		return
	_steam_callback_wrapper("lobby_chat_update", "_on_lobby_chat_update")
	_steam_callback_wrapper("lobby_data_update", "_on_lobby_data_update")
	_steam_callback_wrapper("lobby_message", "_on_lobby_message")


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
	_clear_player_list()

	if _steam == null or not _steam.isSteamRunning():
		info_label.text = "Steam unavailable"
		invite_button.disabled = true
		leave_button.disabled = true
		return

	var steamworks = get_node_or_null("/root/Steamworks")
	var active_lobby_id: int = steamworks.lobby_id if steamworks else 0

	if active_lobby_id > 0:
		var owner_id: int = _steam.getLobbyOwner(active_lobby_id)
		var owner_name: String = _steam.getFriendPersonaName(owner_id)
		var member_count: int = _steam.getNumLobbyMembers(active_lobby_id)
		var max_members: int = _steam.getLobbyMemberLimit(active_lobby_id)
		if max_members <= 0:
			max_members = 4
		info_label.text = "Host: %s (%d/%d)" % [owner_name, member_count, max_members]
		invite_button.disabled = false
		leave_button.disabled = false

		_populate_player_list(active_lobby_id, member_count)
	else:
		info_label.text = "No active lobby"
		invite_button.disabled = true
		leave_button.disabled = true


func _populate_player_list(active_lobby_id: int, member_count: int) -> void:
	if not player_list or lobby_player_item_scene == null:
		return

	for i in range(member_count):
		var member_steam_id: int = _steam.getLobbyMemberByIndex(active_lobby_id, i)
		var item = lobby_player_item_scene.instantiate()
		player_list.add_child(item)
		item.steam_id = member_steam_id
		item.player_kicked.connect(_on_player_kicked)
		item.player_promoted.connect(_on_player_promoted)


func _clear_player_list() -> void:
	if player_list:
		for child in player_list.get_children():
			child.queue_free()


func _on_player_promoted(_steam_id: int) -> void:
	_update_lobby_ui()


func _on_player_kicked(_steam_id: int) -> void:
	_update_lobby_ui()


#region Steam Callbacks
func _on_lobby_chat_update(lobby_id: int, _changed_id: int, _making_change_id: int, _chat_state: int) -> void:
	var steamworks = get_node_or_null("/root/Steamworks")
	var active_lobby_id: int = steamworks.lobby_id if steamworks else 0
	if active_lobby_id == lobby_id and visible:
		_update_lobby_ui()


func _on_lobby_data_update(_success: int, lobby_id: int, _member_id: int) -> void:
	var steamworks = get_node_or_null("/root/Steamworks")
	var active_lobby_id: int = steamworks.lobby_id if steamworks else 0
	if active_lobby_id == lobby_id and visible:
		_update_lobby_ui()


func _on_lobby_message(lobby_id: int, sender: int, message: String, chat_type: int) -> void:
	var steamworks = get_node_or_null("/root/Steamworks")
	var active_lobby_id: int = steamworks.lobby_id if steamworks else 0
	if active_lobby_id != lobby_id:
		return

	# If kick command is sent by lobby owner
	if message.begins_with("/kick ") and _steam != null and sender == _steam.getLobbyOwner(active_lobby_id):
		var parts: PackedStringArray = message.split(" ", false)
		if parts.size() >= 2:
			var target_id: int = int(parts[1])
			var my_id: int = _steam.getSteamID()
			if my_id == target_id:
				# We were kicked
				_on_leave_pressed()


func _steam_callback_wrapper(this_signal: String, this_function: String) -> void:
	var callback_connect: int = _steam.connect(this_signal, Callable(self, this_function))
	if callback_connect > OK:
		printerr("Connecting callback %s to %s failed: %s" % [this_signal, this_function, callback_connect])
#endregion


func _on_invite_pressed() -> void:
	var steamworks = get_node_or_null("/root/Steamworks")
	var active_lobby_id: int = steamworks.lobby_id if steamworks else 0
	if _steam != null and active_lobby_id > 0:
		_steam.activateGameOverlayInviteDialog(active_lobby_id)


func _on_invite_touch_screen_button_pressed() -> void:
	_on_invite_pressed()


func _on_leave_pressed() -> void:
	var steamworks = get_node_or_null("/root/Steamworks")
	var active_lobby_id: int = steamworks.lobby_id if steamworks else 0
	if _steam != null and active_lobby_id > 0:
		_steam.leaveLobby(active_lobby_id)
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
