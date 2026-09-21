class_name LobbyPlayerItem
extends PanelContainer
## One row of the lobby member list; the avatar and name come from the Steam singleton when it is present.

const AVATAR_MEDIUM: int = 2 ## Mirrors Steam.AvatarSizes.AVATAR_MEDIUM (the Steam class is absent on web exports).

signal player_promoted(steam_id: int) ## Emitted after this member is made lobby owner.

var steam_id: int = 0 : set = set_steam_id
var lobby_id: int = 0 ## Set by the lobby manager before [member steam_id].

## Steam singleton when the GodotSteam extension is present, otherwise null; read through [method _steam_session].
var _steam: Object = Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null

@onready var avatar: TextureRect = %Avatar
@onready var host_icon: TextureRect = %HostIcon
@onready var username_label: Label = %Username
@onready var options_button: Button = %OptionsButton
@onready var actions_container: HBoxContainer = %ActionsContainer
@onready var profile_button: Button = %ProfileButton
@onready var achievements_button: Button = %AchievementsButton
@onready var promote_button: Button = %PromoteButton
@onready var kick_button: Button = %KickButton


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if _steam:
		_steam.connect("avatar_loaded", _on_avatar_loaded)


func set_steam_id(new_steam_id: int) -> void:
	steam_id = new_steam_id
	if not is_node_ready():
		await ready
	var steam: Object = _steam_session()
	if steam:
		username_label.text = steam.getFriendPersonaName(steam_id)
		steam.getPlayerAvatar(AVATAR_MEDIUM, steam_id)
	_update_player_state()


## Shows the host badge and, when the local user hosts, the promote/kick actions for other members.
func _update_player_state() -> void:
	var steam: Object = _steam_session()
	var owner_id: int = steam.getLobbyOwner(lobby_id) if steam and lobby_id > 0 else 0
	var local_id: int = steam.getSteamID() if steam else 0
	host_icon.visible = owner_id > 0 and steam_id == owner_id
	var can_moderate: bool = owner_id > 0 and local_id == owner_id and steam_id != local_id
	promote_button.visible = can_moderate
	kick_button.visible = can_moderate


func _on_avatar_loaded(avatar_id: int, size: int, data: PackedByteArray) -> void:
	if avatar_id == steam_id:
		avatar.texture = ImageTexture.create_from_image(Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data))


func _on_options_toggled(toggled_on: bool) -> void:
	actions_container.visible = toggled_on
	username_label.visible = not toggled_on


func _on_profile_pressed() -> void:
	var steam: Object = _steam_session()
	if steam and steam_id > 0:
		steam.activateGameOverlayToUser("steamid", steam_id)


func _on_achievements_pressed() -> void:
	var steam: Object = _steam_session()
	if steam and steam_id > 0:
		steam.activateGameOverlayToUser("achievements", steam_id)


func _on_promote_pressed() -> void:
	var steam: Object = _steam_session()
	if steam and lobby_id > 0 and steam_id > 0:
		steam.setLobbyOwner(lobby_id, steam_id)
		player_promoted.emit(steam_id)
		_update_player_state()


## Asks the owner's client to drop this member; the list refreshes from Steam's lobby_chat_update.
func _on_kick_pressed() -> void:
	var steam: Object = _steam_session()
	if steam and lobby_id > 0 and steam_id > 0:
		steam.sendLobbyChatMsg(lobby_id, "/kick %s" % steam_id)


## The Steam singleton while the Steamworks session is up, else null. The extension being loaded is not enough:
## every lobby call errors without the client running, so the reads wait for [code]/root/Steamworks[/code] to
## report a signed-in [code]steam_id[/code], the way the rest of the addon does.
func _steam_session() -> Object:
	var steamworks: Node = get_node_or_null("/root/Steamworks")
	if steamworks == null or steamworks.get("steam_id") == 0:
		return null
	return _steam
