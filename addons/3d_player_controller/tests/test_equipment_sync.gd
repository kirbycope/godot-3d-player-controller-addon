extends GutTest

## Purpose: what the host equips shows up on the client's copy of the host, and a stack the host drops lands in
## both worlds under one name, so the client taking it frees the host's copy as well. Two scene branches with
## their own MultiplayerAPI talk over ENet on localhost, as test_chat_multiplayer does.

const PORT: int = 47398
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const PLAYER_SPAWNER: Script = preload("res://addons/3d_player_controller/scripts/player_spawner.gd")
const SWORD: Item = preload("res://addons/3d_player_controller/inventory/resources/items/wooden_sword.tres")
const APPLE: Item = preload("res://addons/3d_player_controller/inventory/resources/items/apple.tres")

var server_root: Node3D
var client_root: Node3D
var server_api: SceneMultiplayer
var client_api: SceneMultiplayer


func _build_branch(root: Node3D) -> void:
	var players: Node3D = Node3D.new()
	players.name = "Players"
	root.add_child(players)
	var player_spawner: PlayerSpawner = PLAYER_SPAWNER.new()
	player_spawner.name = "PlayerSpawner"
	player_spawner.spawn_path = NodePath("../Players")
	player_spawner.player_scene = PLAYER_SCENE
	root.add_child(player_spawner)


func before_each() -> void:
	server_root = Node3D.new()
	server_root.name = "ServerBranch"
	client_root = Node3D.new()
	client_root.name = "ClientBranch"
	add_child(server_root)
	add_child(client_root)
	server_api = SceneMultiplayer.new()
	client_api = SceneMultiplayer.new()
	get_tree().set_multiplayer(server_api, server_root.get_path())
	get_tree().set_multiplayer(client_api, client_root.get_path())
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(PORT), OK, "ENet server should open on localhost")
	server_api.multiplayer_peer = server_peer
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", PORT), OK)
	client_api.multiplayer_peer = client_peer
	_build_branch(server_root)
	_build_branch(client_root)
	for i: int in 120:
		await wait_process_frames(1)
		if client_api.get_peers().size() > 0 and server_api.get_peers().size() > 0:
			break
	assert_gt(client_api.get_peers().size(), 0, "Client should connect to the loopback server")


func after_each() -> void:
	var server_path: NodePath = server_root.get_path()
	var client_path: NodePath = client_root.get_path()
	server_root.free()
	client_root.free()
	server_api.multiplayer_peer.close()
	client_api.multiplayer_peer.close()
	get_tree().set_multiplayer(null, server_path)
	get_tree().set_multiplayer(null, client_path)


func test_the_hosts_equipment_and_drops_reach_the_client() -> void:
	await wait_process_frames(30)
	var client_id: String = str(client_api.get_unique_id())
	var host: Player = server_root.get_node("Players/1")
	var host_on_client: Player = client_root.get_node("Players/1")
	var client: Player = client_root.get_node("Players/" + client_id)

	host.inventory.add_item(SWORD)
	assert_true(host.inventory.has_equipment(Equipment.EquipmentType.SWORD_1H))
	await wait_process_frames(10)
	assert_true(host_on_client.inventory.has_equipment(Equipment.EquipmentType.SWORD_1H), "The client's copy of the host wears the sword")
	assert_true(host_on_client.equipped_sword_1h, "so its AnimationTree holds the stance")
	host.inventory.unequip_all()
	await wait_process_frames(10)
	assert_false(host_on_client.inventory.has_equipment(Equipment.EquipmentType.SWORD_1H), "Stowed there, stowed here")
	assert_eq(host_on_client.inventory.get_all_weapons().size(), 1, "but still carried")

	host.inventory.add_item(APPLE, 2)
	var dropped: Node3D = host.inventory.drop_slot(Item.Category.FOOD, 0, 1)
	assert_eq(dropped.name, "Dropped_1_1")
	await wait_process_frames(10)
	var on_client: ItemPickup = client_root.get_node_or_null("Players/Dropped_1_1") as ItemPickup
	assert_not_null(on_client, "The drop landed in the client's world under the same name")
	if on_client == null:
		return
	assert_eq(on_client.item, APPLE)
	assert_eq(on_client.count, 1)
	on_client.player = client # as walking up to it would
	on_client.take()
	await wait_process_frames(10)
	assert_eq(client.inventory.count_of(APPLE), 1, "The client took the apple")
	assert_false(is_instance_valid(dropped), "and the host's copy went with it")


## A weapon placed in a level is usually the model file with the Equipment script and its settings put on in
## the scene, so the model's path alone re-creates nothing. The copy names the pickup it came from instead, and
## a peer duplicates that pickup: for wearing, and again when it is dropped.
func test_a_world_pickup_reaches_the_client_by_its_path() -> void:
	await wait_process_frames(30)
	var host: Player = server_root.get_node("Players/1")
	var host_on_client: Player = client_root.get_node("Players/1")
	var pickup: Equipment = Equipment.new()
	pickup.name = "WorldSword"
	pickup.equipment_type = Equipment.EquipmentType.SWORD_1H
	pickup.bone_attachment_bone_name = "RightHand"
	server_root.add_child(pickup)
	assert_true(pickup.equip(host), "The host picks the sword up off the ground")
	var worn: Equipment = pickup.equipment_instance
	assert_eq(worn.get_meta("origin"), String(pickup.get_path()), "and the copy remembers the pickup it came from")
	await wait_process_frames(10)
	assert_true(host_on_client.inventory.has_equipment(Equipment.EquipmentType.SWORD_1H), "The client's copy of the host wears it")
	var on_client: Equipment = host_on_client.inventory.get_all_weapons()[0] as Equipment
	assert_eq(on_client.bone_attachment_bone_name, "RightHand", "with the settings the level gave the pickup")
	var dropped: Node3D = host.inventory.drop_equipment(worn)
	assert_not_null(dropped, "The host drops it")
	await wait_process_frames(10)
	var drop_on_client: Equipment = client_root.get_node_or_null("Players/Dropped_1_1") as Equipment
	assert_not_null(drop_on_client, "and it lies in the client's world as a whole pickup, script and all")
	if drop_on_client:
		assert_null(drop_on_client.equipment_instance, "ready to be picked up again")
