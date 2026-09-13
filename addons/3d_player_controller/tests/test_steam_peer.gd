extends GutTest
## Purpose: SteamPeer has to tell a session it made from Godot's default peer. Every tree carries an
## OfflineMultiplayerPeer from the start, so "has a multiplayer peer" is always true and can never mean
## "already hosting or connected"; asking that made both the host and the client path return early, and no
## Steam session ever formed even with the lobby joined on both sides.

const STEAM_PEER: Script = preload("res://addons/3d_player_controller/scripts/steam_peer.gd")


func test_the_default_offline_peer_is_not_a_session() -> void:
	var peer: SteamPeer = STEAM_PEER.new()
	add_child_autofree(peer)
	var was: MultiplayerPeer = peer.multiplayer.multiplayer_peer
	assert_true(peer.multiplayer.has_multiplayer_peer(), "Godot always answers yes here, which is the trap")
	assert_false(peer.has_session(), "so that is not what the guard asks")
	var enet: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	enet.create_server(47393)
	peer.multiplayer.multiplayer_peer = enet
	assert_true(peer.has_session(), "a real peer is a session")
	peer.multiplayer.multiplayer_peer = was
	enet.close()
