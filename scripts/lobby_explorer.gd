extends CanvasLayer

const LOBBY_EXPLORER_ENTRY = preload("res://addons/3d_player_controller/scenes/lobby_explorer_entry.tscn")

@export_file("*.tscn") var world_scene: String = "res://scenes/world.tscn"
@export_file("*.tscn") var title_scene: String = "res://scenes/main.tscn"

@onready var loading: Loading = $Loading
@onready var host_button: Button = %Button_Host
@onready var refresh_button: Button = %Button_Refresh
@onready var back_button: Button = %Button_Back
@onready var status_label: Label = %StatusLabel
@onready var lobby_list: VBoxContainer = %LobbyList
@onready var distance_option: OptionButton = %DistanceOption
@onready var label_version: Label = $Label_Version
@onready var label_copyright: Label = $Label_Copyright


func _ready() -> void:
	_setup_meta_labels()
	_setup_distance_options()
	_connect_signals()
	_connect_steam_signals()

	if not Engine.has_singleton("Steam") or not Steam.isSteamRunning():
		status_label.text = "Steam is not running. Lobby features disabled."
		host_button.disabled = true
		refresh_button.disabled = true
	else:
		refresh_lobbies()


func _setup_meta_labels() -> void:
	if label_version:
		var version: String = ProjectSettings.get_setting("application/config/version", "")
		label_version.text = version if version.begins_with("v") else "v" + version
	if label_copyright:
		var current_year: int = Time.get_date_dict_from_system().year
		label_copyright.text = "© Timothy Cope %d" % current_year


func _setup_distance_options() -> void:
	if not distance_option:
		return
	distance_option.clear()
	distance_option.add_item("Close", 0)
	distance_option.add_item("Default", 1)
	distance_option.add_item("Far", 2)
	distance_option.add_item("Worldwide", 3)
	distance_option.selected = 1


func _connect_signals() -> void:
	if host_button:
		host_button.pressed.connect(_on_host_pressed)
	if refresh_button:
		refresh_button.pressed.connect(refresh_lobbies)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if distance_option:
		distance_option.item_selected.connect(_on_distance_filter_changed)


func _connect_steam_signals() -> void:
	if not Engine.has_singleton("Steam"):
		return
	_steam_callback_wrapper("lobby_match_list", "_on_lobby_match_list")
	_steam_callback_wrapper("lobby_joined", "_on_lobby_joined")


func refresh_lobbies() -> void:
	if not Engine.has_singleton("Steam") or not Steam.isSteamRunning():
		return

	_clear_lobby_list()
	status_label.text = "Searching for lobbies..."

	var distance_filter: int = distance_option.selected if distance_option else 1
	Steam.addRequestLobbyListDistanceFilter(distance_filter)
	Steam.addRequestLobbyListFilterSlotsAvailable(1)
	Steam.addRequestLobbyListResultCountFilter(50)
	Steam.requestLobbyList()


func _clear_lobby_list() -> void:
	if lobby_list:
		for child in lobby_list.get_children():
			child.queue_free()


func _on_distance_filter_changed(_index: int) -> void:
	refresh_lobbies()


func _on_host_pressed() -> void:
	if loading and not world_scene.is_empty():
		loading.load_scene(world_scene)
	elif not world_scene.is_empty():
		get_tree().change_scene_to_file(world_scene)


func _on_back_pressed() -> void:
	if loading and not title_scene.is_empty():
		loading.load_scene(title_scene)
	elif not title_scene.is_empty():
		get_tree().change_scene_to_file(title_scene)


func _on_touch_host_pressed() -> void:
	_on_host_pressed()


func _on_touch_refresh_pressed() -> void:
	refresh_lobbies()


func _on_touch_back_pressed() -> void:
	_on_back_pressed()


func _on_join_lobby_requested(lobby_id: int) -> void:
	status_label.text = "Joining lobby %d..." % lobby_id
	if Engine.has_singleton("Steam"):
		Steam.joinLobby(lobby_id)


#region Steam Callbacks
func _on_lobby_match_list(lobbies: Array) -> void:
	_clear_lobby_list()

	if lobbies.is_empty():
		status_label.text = "No public lobbies found. Click 'Host Game' to create one!"
		return

	status_label.text = "Found %d active lobbies" % lobbies.size()

	for lobby_id in lobbies:
		var entry = LOBBY_EXPLORER_ENTRY.instantiate()
		lobby_list.add_child(entry)
		entry.lobby_id = lobby_id
		entry.join_requested.connect(_on_join_lobby_requested)


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: int, response: int) -> void:
	# ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_SUCCESS == 1
	if response == 1:
		status_label.text = "Joined lobby %d! Loading world..." % lobby_id
		var steamworks = get_node_or_null("/root/Steamworks")
		if steamworks:
			steamworks.lobby_id = lobby_id
		if loading and not world_scene.is_empty():
			loading.load_scene(world_scene)
		elif not world_scene.is_empty():
			get_tree().change_scene_to_file(world_scene)
	else:
		status_label.text = "Failed to join lobby (Response code: %d)" % response


func _steam_callback_wrapper(this_signal: String, this_function: String) -> void:
	var callback_connect: int = Steam.connect(this_signal, Callable(self, this_function))
	if callback_connect > OK:
		printerr("Connecting callback %s to %s failed: %s" % [this_signal, this_function, callback_connect])
#endregion
