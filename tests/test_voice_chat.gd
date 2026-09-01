extends GutTest

const PLAYER_SCENE = preload("res://addons/3d_player_controller/scenes/player.tscn")
const CONTROLS_SCENE = preload("res://addons/3d_player_controller/scenes/controls.tscn")


func test_broadcast_action_in_input_map() -> void:
	var controls = CONTROLS_SCENE.instantiate()
	add_child_autofree(controls)

	assert_true(InputMap.has_action("broadcast"), "InputMap should have 'broadcast' action")

	var events = InputMap.action_get_events("broadcast")
	var has_key_t: bool = false
	for event in events:
		if event is InputEventKey and event.physical_keycode == KEY_T:
			has_key_t = true
			break
	assert_true(has_key_t, "'broadcast' action should be mapped to physical key T")


func test_player_voice_chat_nodes_and_default_state() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	assert_not_null(player.voice_chat_indicator, "VoiceChatIndicator should exist on Player")
	assert_false(player.voice_chat_indicator.visible, "VoiceChatIndicator should be hidden by default")
	assert_not_null(player.voice_audio_player, "VoiceAudioPlayer should exist on Player")
	assert_false(player.is_broadcasting, "is_broadcasting should be false by default")


func test_player_broadcasting_indicator_toggle() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	player.start_broadcasting()
	assert_true(player.is_broadcasting, "Player is_broadcasting should be true after start_broadcasting()")
	assert_true(player.voice_chat_indicator.visible, "VoiceChatIndicator should be visible when broadcasting")

	player.stop_broadcasting()
	assert_false(player.is_broadcasting, "Player is_broadcasting should be false after stop_broadcasting()")
	assert_false(player.voice_chat_indicator.visible, "VoiceChatIndicator should be hidden when not broadcasting")
