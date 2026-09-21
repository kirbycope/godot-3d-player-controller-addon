class_name LobbyExplorerEntry
extends PanelContainer
## One row of the lobby explorer list.

signal join_requested(lobby_id: int)

var lobby_id: int = 0 : set = set_lobby_id

## Steam singleton when the GodotSteam extension is present, otherwise null; read through [method _steam_session].
var _steam: Object = Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null

@onready var name_label: Label = %NameLabel
@onready var count_label: Label = %CountLabel
@onready var join_button: Button = %JoinButton


func set_lobby_id(new_id: int) -> void:
	lobby_id = new_id
	if not is_node_ready():
		await ready
	var steam: Object = _steam_session()
	if steam == null:
		name_label.text = "Lobby %d" % lobby_id
		count_label.text = "1/4"
		return

	var lobby_name: String = steam.getLobbyData(lobby_id, "lobby_name")
	if lobby_name.is_empty():
		lobby_name = steam.getLobbyData(lobby_id, "name")
	if lobby_name.is_empty():
		var owner_id: int = steam.getLobbyOwner(lobby_id)
		lobby_name = "%s's Lobby" % steam.getFriendPersonaName(owner_id) if owner_id > 0 else "Lobby %d" % lobby_id
	name_label.text = lobby_name

	var max_members: int = steam.getLobbyMemberLimit(lobby_id)
	count_label.text = "%d/%d" % [steam.getNumLobbyMembers(lobby_id), max_members if max_members > 0 else 4]


func _on_join_pressed() -> void:
	join_requested.emit(lobby_id)


func _on_touch_screen_button_pressed() -> void:
	_on_join_pressed()


## The Steam singleton while the Steamworks session is up, else null. The extension being loaded is not enough:
## every lobby call errors without the client running, so the reads wait for [code]/root/Steamworks[/code] to
## report a signed-in [code]steam_id[/code], the way the rest of the addon does.
func _steam_session() -> Object:
	var steamworks: Node = get_node_or_null("/root/Steamworks")
	if steamworks == null or steamworks.get("steam_id") == 0:
		return null
	return _steam
