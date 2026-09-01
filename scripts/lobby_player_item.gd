extends PanelContainer

## Signal emitted when the player is kicked or ownership changed
signal player_promoted(steam_id: int)
signal player_kicked(steam_id: int)

var steam_id: int = 0 : set = set_steam_id

## Steam singleton when the GodotSteam extension is present, otherwise null.
var _steam: Object = Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null

@onready var avatar: SteamAvatarRect = %Avatar
@onready var host_icon: TextureRect = %HostIcon
@onready var username_label: SteamUsername = %Username
@onready var options_button: Button = %OptionsButton
@onready var actions_container: HBoxContainer = %ActionsContainer
@onready var profile_button: Button = %ProfileButton
@onready var achievements_button: Button = %AchievementsButton
@onready var promote_button: Button = %PromoteButton
@onready var kick_button: Button = %KickButton


func _ready() -> void:
	_connect_signals()
	_update_player_state()


func _connect_signals() -> void:
	if options_button:
		options_button.toggled.connect(_on_options_toggled)
	if profile_button:
		profile_button.pressed.connect(_on_profile_pressed)
	if achievements_button:
		achievements_button.pressed.connect(_on_achievements_pressed)
	if promote_button:
		promote_button.pressed.connect(_on_promote_pressed)
	if kick_button:
		kick_button.pressed.connect(_on_kick_pressed)


func set_steam_id(new_steam_id: int) -> void:
	steam_id = new_steam_id
	if not is_node_ready():
		await ready
	if avatar:
		avatar.steam_id = steam_id
	if username_label:
		username_label.steam_id = steam_id
	_update_player_state()


func _update_player_state() -> void:
	var is_steam_active: bool = _steam != null and _steam.isSteamRunning()
	var steamworks = get_node_or_null("/root/Steamworks")
	var active_lobby_id: int = steamworks.lobby_id if steamworks else 0
	var local_steam_id: int = steamworks.steam_id if steamworks and "steam_id" in steamworks else (_steam.getSteamID() if is_steam_active else 0)

	var is_owner: bool = false
	var am_i_host: bool = false

	if is_steam_active and active_lobby_id > 0:
		var owner_id: int = _steam.getLobbyOwner(active_lobby_id)
		is_owner = (steam_id == owner_id)
		am_i_host = (local_steam_id == owner_id)

	if host_icon:
		host_icon.visible = is_owner

	# Host actions (promote / kick) only visible if local user is host and target is not self
	var can_moderate: bool = am_i_host and (steam_id != local_steam_id)
	if promote_button:
		promote_button.visible = can_moderate
	if kick_button:
		kick_button.visible = can_moderate


func _on_options_toggled(toggled_on: bool) -> void:
	if actions_container:
		actions_container.visible = toggled_on
	if username_label:
		username_label.visible = not toggled_on


func _on_profile_pressed() -> void:
	if _steam != null and steam_id > 0:
		_steam.activateGameOverlayToUser("steamid", steam_id)


func _on_achievements_pressed() -> void:
	if _steam != null and steam_id > 0:
		_steam.activateGameOverlayToUser("achievements", steam_id)


func _on_promote_pressed() -> void:
	var steamworks = get_node_or_null("/root/Steamworks")
	var active_lobby_id: int = steamworks.lobby_id if steamworks else 0
	if _steam != null and active_lobby_id > 0 and steam_id > 0:
		_steam.setLobbyOwner(active_lobby_id, steam_id)
		player_promoted.emit(steam_id)
		_update_player_state()


func _on_kick_pressed() -> void:
	var steamworks = get_node_or_null("/root/Steamworks")
	var active_lobby_id: int = steamworks.lobby_id if steamworks else 0
	if _steam != null and active_lobby_id > 0 and steam_id > 0:
		_steam.sendLobbyChatMsg(active_lobby_id, "/kick %s" % steam_id)
		player_kicked.emit(steam_id)
