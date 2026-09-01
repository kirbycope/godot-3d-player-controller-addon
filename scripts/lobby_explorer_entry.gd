extends PanelContainer

signal join_requested(lobby_id: int)

var lobby_id: int = 0 : set = set_lobby_id

@onready var name_label: Label = %NameLabel
@onready var count_label: Label = %CountLabel
@onready var join_button: Button = %JoinButton


func _ready() -> void:
	if join_button:
		join_button.pressed.connect(_on_join_pressed)


func set_lobby_id(new_id: int) -> void:
	lobby_id = new_id
	if not is_node_ready():
		await ready
	_update_entry()


func _update_entry() -> void:
	if not Engine.has_singleton("Steam"):
		if name_label:
			name_label.text = "Lobby %d" % lobby_id
		if count_label:
			count_label.text = "1/4"
		return

	var lobby_name: String = Steam.getLobbyData(lobby_id, "lobby_name")
	if lobby_name.is_empty():
		lobby_name = Steam.getLobbyData(lobby_id, "name")
	if lobby_name.is_empty():
		var owner_id: int = Steam.getLobbyOwner(lobby_id)
		if owner_id > 0:
			lobby_name = "%s's Lobby" % Steam.getFriendPersonaName(owner_id)
		else:
			lobby_name = "Lobby %d" % lobby_id

	var member_count: int = Steam.getNumLobbyMembers(lobby_id)
	var max_members: int = Steam.getLobbyMemberLimit(lobby_id)
	if max_members <= 0:
		max_members = 4

	if name_label:
		name_label.text = lobby_name
	if count_label:
		count_label.text = "%d/%d" % [member_count, max_members]


func _on_join_pressed() -> void:
	join_requested.emit(lobby_id)


func _on_touch_screen_button_pressed() -> void:
	_on_join_pressed()
