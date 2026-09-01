extends GutTest

const PLAYER_SCENE = preload("res://addons/3d_player_controller/scenes/player.tscn")
const CONTROLS_SCENE = preload("res://addons/3d_player_controller/scenes/controls.tscn")


func test_focus_target_cycling_between_multiple_targets() -> void:
	var controls = CONTROLS_SCENE.instantiate()
	add_child_autofree(controls)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	var focus_node: Focus = player.get_node("Focus") as Focus
	assert_not_null(focus_node, "Focus node should exist on player")

	# Create 3 targets around the player
	var target1 = CharacterBody3D.new()
	target1.name = "Target1"
	target1.add_to_group("Target")
	add_child_autofree(target1)
	target1.global_position = player.global_position + Vector3(0, 0, -5)

	var target2 = CharacterBody3D.new()
	target2.name = "Target2"
	target2.add_to_group("Target")
	add_child_autofree(target2)
	target2.global_position = player.global_position + Vector3(5, 0, -5)

	var target3 = CharacterBody3D.new()
	target3.name = "Target3"
	target3.add_to_group("Target")
	add_child_autofree(target3)
	target3.global_position = player.global_position + Vector3(-5, 0, -5)

	# Initial focus lock-on
	Input.action_press("focus")
	focus_node._physics_process(0.1)
	assert_not_null(focus_node.current_focus_target, "Focus should acquire initial target")
	var initial_target = focus_node.current_focus_target

	# Cycle target forward
	focus_node.cycle_focus_target(1)
	assert_not_null(focus_node.current_focus_target, "Focus should have a target after cycle")
	assert_ne(focus_node.current_focus_target, initial_target, "Focus should cycle to a new target")

	var second_target = focus_node.current_focus_target

	# Cycle target forward again
	focus_node.cycle_focus_target(1)
	assert_ne(focus_node.current_focus_target, second_target, "Focus should cycle to the third target")

	# Cycle back
	focus_node.cycle_focus_target(-1)
	assert_eq(focus_node.current_focus_target, second_target, "Focus should cycle back to second target")

	Input.action_release("focus")
	focus_node._physics_process(0.1)
	assert_null(focus_node.current_focus_target, "Focus target should clear after release")


func test_target_loss_grace_period() -> void:
	var controls = CONTROLS_SCENE.instantiate()
	add_child_autofree(controls)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	var focus_node: Focus = player.get_node("Focus") as Focus

	var target = CharacterBody3D.new()
	target.name = "TargetFar"
	target.add_to_group("Target")
	add_child_autofree(target)
	target.global_position = player.global_position + Vector3(0, 0, -5)

	Input.action_press("focus")
	focus_node._physics_process(0.1)
	assert_eq(focus_node.current_focus_target, target, "Focus should lock on to target")

	# Move target beyond max_focus_distance (e.g. 50m)
	target.global_position = player.global_position + Vector3(0, 0, -50)

	# Process 0.2s (less than 0.5s grace time) -> Target should still be locked
	focus_node._physics_process(0.2)
	assert_eq(focus_node.current_focus_target, target, "Target should still be locked during grace period")

	# Process remaining grace time (e.g. 0.4s more, total > 0.5s) -> Target should drop
	focus_node._physics_process(0.4)
	assert_null(focus_node.current_focus_target, "Target should be dropped after grace period expires")

	Input.action_release("focus")
