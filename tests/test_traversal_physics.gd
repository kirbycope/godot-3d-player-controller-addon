extends GutTest

const PLAYER_SCENE = preload("res://addons/3d_player_controller/scenes/player.tscn")
const CONTROLS_SCENE = preload("res://addons/3d_player_controller/scenes/controls.tscn")


func test_climbing_wall_back_eject_leap() -> void:
	var controls = CONTROLS_SCENE.instantiate()
	add_child_autofree(controls)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	var climbing_node = player.get_node("NodeStateMachine/Climbing")
	assert_not_null(climbing_node, "Climbing state node should exist")

	# Set player in climbing state in air
	player.current_state = NodeStateMachine.States.CLIMBING
	player.is_climbing = true
	player.locomotion_state.start("ClimbingLocomotion")
	player.animation_tree.advance(0.01)

	# Hold down/back input on wall
	player.player_input.motion = Vector2(0, -1.0)

	var event = InputEventAction.new()
	event.action = "jump"
	event.pressed = true
	climbing_node._input(event)

	assert_true(player.is_falling, "Player should enter falling state after back-eject")
	assert_gt(player.velocity.y, 0.0, "Player should have upward impulse from back-eject leap")
	assert_false(player.is_climbing, "Player should no longer be climbing")


func test_paragliding_thermal_updraft_and_steep_dive() -> void:
	var controls = CONTROLS_SCENE.instantiate()
	add_child_autofree(controls)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	player.enable_stamina = true

	var paragliding_node: Paragliding = player.get_node("NodeStateMachine/Paragliding") as Paragliding
	assert_not_null(paragliding_node, "Paragliding state node should exist")

	paragliding_node.start()
	assert_true(player.is_paragliding, "Player should be paragliding")

	# 1. Test normal descent
	player.velocity = Vector3(0, 0, 0)
	paragliding_node._physics_process(0.1)
	assert_lt(player.velocity.y, 0.0, "Normal paragliding should have gentle descent")

	# 2. Test steep dive
	Input.action_press("crouch")
	player.velocity = Vector3(0, 0, 0)
	paragliding_node._physics_process(0.5)
	var dive_vy = player.velocity.y
	assert_lt(dive_vy, -4.0, "Steep dive should produce high downward descent rate")
	Input.action_release("crouch")

	# 3. Test thermal updraft lift
	var updraft = Area3D.new()
	updraft.add_to_group("Updraft")
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(20, 20, 20)
	col.shape = box
	updraft.add_child(col)
	add_child_autofree(updraft)
	updraft.global_position = player.global_position

	player.stamina.value = 50.0
	paragliding_node._physics_process(0.5)
	assert_gt(player.velocity.y, 0.0, "Updraft should provide upward lift")
	assert_gt(player.stamina.value, 50.0, "Updraft should replenish stamina")

	paragliding_node.stop()


func test_swimming_exhaustion_shore_respawn() -> void:
	var controls = CONTROLS_SCENE.instantiate()
	add_child_autofree(controls)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)

	var swimming_node: Swimming = player.get_node("NodeStateMachine/Swimming") as Swimming
	assert_not_null(swimming_node, "Swimming state node should exist")

	# Establish safe shore position on land
	var shore_pos = Vector3(10, 0, 10)
	player.global_position = shore_pos
	player.last_safe_shore_position = shore_pos

	# Enter deep water far away
	var water_pos = Vector3(50, -5, 50)
	player.global_position = water_pos
	player.is_swimming = true
	player.current_state = NodeStateMachine.States.SWIMMING

	# Exhaust player in deep water
	player.is_exhausted = true
	swimming_node._physics_process(0.1)

	assert_eq(player.global_position, shore_pos, "Exhausted swimmer should respawn at last safe shore position")
	assert_false(player.is_swimming, "Swimmer should no longer be swimming after shore respawn")
	assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Swimmer should be in standing state on shore")
