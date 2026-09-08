extends GutTest

## Purpose: the pause menu pauses the scene tree only when the Player plays alone: offline (no peer, Steam not
## loaded) and as a connected host nobody has joined. A client never pauses the world, a peer joining a paused
## host resumes it with the menu still up, a sub-menu opened from Pause keeps the pause until it closes, closing
## resumes, and a menu freed while paused resumes. Two branches over ENet on localhost stand in for the Steam session.

const PORT: int = 47397
const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")

var root: Node3D
var player: Player


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	await wait_physics_frames(2)


func after_each() -> void:
	get_tree().paused = false
	if is_instance_valid(root):
		root.free()
		root = null


func test_offline_the_pause_menu_pauses_the_world_and_resume_runs_it_again() -> void:
	assert_true(player.pause.pauses_world, "pause.tscn pauses the world")
	assert_true(player.pause.is_single_player(), "No peer means playing alone")
	assert_eq(player.pause.process_mode, Node.PROCESS_MODE_ALWAYS, "The menu keeps working while the tree is paused")
	player.pause.show_menu()
	assert_true(get_tree().paused, "The world stands still")
	assert_true(player.is_paused)
	player.pause.hide_menu()
	assert_false(get_tree().paused, "Resume runs it again")
	assert_false(player.is_paused)


func test_a_sub_menu_opened_from_pause_keeps_the_world_paused_until_it_closes() -> void:
	player.pause.show_menu()
	player.pause._on_settings_pressed()
	assert_false(player.pause.visible)
	assert_true(player.settings.visible)
	assert_true(get_tree().paused, "Settings opened from Pause keeps the pause")
	assert_false(player.settings.pauses_world, "though Settings on its own would not pause")
	player.settings.hide_menu()
	assert_false(get_tree().paused, "Closing the sub-menu resumes")


func test_a_menu_freed_while_paused_lets_the_world_go() -> void:
	player.pause.show_menu()
	assert_true(get_tree().paused)
	root.free()
	root = null
	assert_false(get_tree().paused, "The Player despawning (a scene change) never leaves the tree paused")


func test_only_a_connected_host_alone_pauses_and_a_joining_peer_resumes() -> void:
	var server_root := Node3D.new()
	server_root.name = "ServerBranch"
	var client_root := Node3D.new()
	client_root.name = "ClientBranch"
	add_child(server_root)
	add_child(client_root)
	var server_api := SceneMultiplayer.new()
	var client_api := SceneMultiplayer.new()
	get_tree().set_multiplayer(server_api, server_root.get_path())
	get_tree().set_multiplayer(client_api, client_root.get_path())
	var server_peer := ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(PORT), OK, "ENet server should open on localhost")
	server_api.multiplayer_peer = server_peer
	var host: Player = PLAYER_SCENE.instantiate()
	server_root.add_child(host)
	var guest: Player = PLAYER_SCENE.instantiate() # the client's copy of the host's player, at the same path
	client_root.add_child(guest)
	await wait_physics_frames(2)
	assert_true(host.pause.is_single_player(), "A connected host with nobody joined plays alone")
	host.pause.show_menu()
	assert_true(get_tree().paused, "so the pause menu pauses the world")

	var client_peer := ENetMultiplayerPeer.new()
	assert_eq(client_peer.create_client("127.0.0.1", PORT), OK)
	client_api.multiplayer_peer = client_peer
	for i in 120:
		await wait_process_frames(1)
		if client_api.get_peers().size() > 0 and server_api.get_peers().size() > 0:
			break
	assert_gt(server_api.get_peers().size(), 0, "The client joins")
	assert_false(get_tree().paused, "A peer joining resumes the world")
	assert_true(host.pause.visible, "with the menu still up")
	assert_false(host.pause.is_single_player(), "and the host is no longer alone")
	host.pause.hide_menu()
	host.pause.show_menu()
	assert_false(get_tree().paused, "Pausing again in company only pauses the Player")
	assert_true(host.is_paused)
	host.pause.hide_menu()

	assert_false(guest.pause.is_single_player(), "A client is never alone")
	guest.pause.show_menu()
	assert_false(get_tree().paused, "so its pause menu never pauses the world")
	guest.pause.hide_menu()

	var server_path: NodePath = server_root.get_path()
	var client_path: NodePath = client_root.get_path()
	server_root.free()
	client_root.free()
	server_api.multiplayer_peer.close()
	client_api.multiplayer_peer.close()
	get_tree().set_multiplayer(null, server_path)
	get_tree().set_multiplayer(null, client_path)
