class_name PlayerSpawner
extends MultiplayerSpawner
## Spawns one [member player_scene] per peer under [member MultiplayerSpawner.spawn_path], named by peer id.
##
## The server (also the case offline, where the local id is 1) spawns itself on ready and every peer
## that connects; the scene replicates to clients through the spawner. [Player] reads its authority from
## its node name in [code]_enter_tree[/code], so each copy runs input only on the peer that owns it.

signal local_player_spawned(player: Player) ## The player this peer controls has entered the tree.

@export var player_scene: PackedScene ## Must be the Player scene (or one inheriting it).
@export var spawn_point: Node3D ## Optional; players appear here instead of at the container origin.


func _ready() -> void:
	if player_scene:
		add_spawnable_scene(player_scene.resource_path)
	spawned.connect(_on_spawned)
	multiplayer.peer_connected.connect(spawn_player)
	multiplayer.peer_disconnected.connect(despawn_player)
	if multiplayer.is_server():
		spawn_player(multiplayer.get_unique_id())


## Server only: adds the player node for [param peer_id]; the spawner replicates it.
func spawn_player(peer_id: int) -> void:
	if not multiplayer.is_server() or player_scene == null:
		return
	var container: Node = get_node(spawn_path)
	if container.has_node(str(peer_id)):
		return
	var player: Player = player_scene.instantiate()
	player.name = str(peer_id)
	if spawn_point:
		player.position = spawn_point.global_position
	container.add_child(player)
	_on_spawned(player)


func despawn_player(peer_id: int) -> void:
	var player: Node = get_node(spawn_path).get_node_or_null(str(peer_id))
	if player:
		player.queue_free()


## The player controlled by this peer, or null before it spawns.
func get_local_player() -> Player:
	return get_node(spawn_path).get_node_or_null(str(multiplayer.get_unique_id())) as Player


func _on_spawned(node: Node) -> void:
	if node is Player and node.is_multiplayer_authority():
		local_player_spawned.emit(node)
