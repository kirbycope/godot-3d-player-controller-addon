extends GutTest

const PLAYER_SCENE = preload("res://addons/3d_player_controller/scenes/player.tscn")


func test_player_synchronizer_node_exists() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	assert_not_null(player.player_synchronizer, "Player should have PlayerSynchronizer node")
	assert_true(player.player_synchronizer is MultiplayerSynchronizer, "PlayerSynchronizer should be a MultiplayerSynchronizer")
	assert_not_null(player.player_synchronizer.replication_config, "PlayerSynchronizer should have a SceneReplicationConfig")


func test_player_synchronizer_properties_tracked() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	var config: SceneReplicationConfig = player.player_synchronizer.replication_config
	assert_not_null(config, "Replication config must not be null")

	var tracked_properties: Array[NodePath] = config.get_properties()
	assert_true(tracked_properties.has(NodePath(".:position")), "Should track player position")
	assert_true(tracked_properties.has(NodePath(".:rotation")), "Should track player rotation")
	assert_true(tracked_properties.has(NodePath("PlayerModel:position")), "Should track PlayerModel position")
	assert_true(tracked_properties.has(NodePath("PlayerModel:rotation")), "Should track PlayerModel rotation")
	assert_true(tracked_properties.has(NodePath(".:sync_locomotion_node")), "Should track sync_locomotion_node")
	assert_true(tracked_properties.has(NodePath(".:sync_blend_position")), "Should track sync_blend_position")
	assert_true(tracked_properties.has(NodePath(".:current_state")), "Should track current_state")


func test_animation_sync_properties_update() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	# Test blend position update
	player.sync_blend_position = Vector2(0.5, 0.8)
	assert_eq(player.sync_blend_position, Vector2(0.5, 0.8), "sync_blend_position should store blend coordinates")

	# Test locomotion node name update
	player.sync_locomotion_node = "StandingLocomotion"
	assert_eq(player.sync_locomotion_node, "StandingLocomotion", "sync_locomotion_node should store state name")
