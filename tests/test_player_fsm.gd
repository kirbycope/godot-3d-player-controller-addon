extends GutTest

## Purpose: To test the state transitions of the Player FSM.

class FsmTestBase:
	extends IntegrationTestBase

	var PlayerScene = load("res://addons/3d_player_controller/scenes/player.tscn")
	var root: Node3D
	var player: Player
	var floor_body: StaticBody3D
	var wall: StaticBody3D
	
	func before_each() -> void:
		root = Node3D.new()
		add_child_autofree(root)
		
		# Create floor
		floor_body = StaticBody3D.new()
		var floor_shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(100, 1, 100)
		floor_shape.shape = box
		floor_body.add_child(floor_shape)
		floor_body.position = Vector3(0, -0.5, 0)
		root.add_child(floor_body)
		
		# Create walls for climbing (surrounding player closely so 1m raycast hits)
		for dir in [Vector3(0, 0, -1.2), Vector3(0, 0, 1.2), Vector3(-1.2, 0, 0), Vector3(1.2, 0, 0)]:
			var w = StaticBody3D.new()
			var w_shape = CollisionShape3D.new()
			var w_box = BoxShape3D.new()
			if dir.z != 0:
				w_box.size = Vector3(10, 10, 1)
			else:
				w_box.size = Vector3(1, 10, 10)
			w_shape.shape = w_box
			w.add_child(w_shape)
			w.position = dir + Vector3(0, 5, 0)
			root.add_child(w)
		
		# Instantiate Player
		player = PlayerScene.instantiate()
		root.add_child(player)
		player.position = Vector3(0, 0.1, 0) # Slightly above floor to snap down
		
		# Await physics frames so state machine can boot
		await wait_physics_frames(2)

	func after_each() -> void:
		Input.action_release("jump")
		Input.action_release("sprint")
		Input.action_release("crouch")
		Input.action_release("attack")
		Input.action_release("move_up")
		Input.action_release("ui_down")
		Input.action_release("whistle")
		if is_instance_valid(root):
			root.free()
			root = null
			player = null

class TestStandingTransitions:
	extends FsmTestBase
	
	func test_standing_to_jumping():
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should start in STANDING state.")
		
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("jump")
		await wait_physics_frames(2)
		sender.action_up("jump")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.JUMPING, "Player should transition to JUMPING state after jump action.")

	func test_exhausted_player_can_jump():
		player.enable_stamina = true
		var stamina: Node = player.get_node("Stamina")
		stamina.set("stamina", 0.0)
		player.is_exhausted = true
		await wait_physics_frames(15)
		assert_eq(player.current_locomotion_node, "HeavyBreathing")

		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("jump")
		await wait_physics_frames(2)
		sender.action_up("jump")
		await wait_physics_frames(45)

		assert_ne(player.current_locomotion_node, "HeavyBreathing")
		assert_false(
				player.is_jump_queued,
				"Jump queue should execute from %s." % player.current_locomotion_node,
		)
		assert_false(
				player.is_on_floor(),
				"Player should leave floor from %s." % player.current_locomotion_node,
		)
		
	func test_standing_to_sprinting():
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should start in STANDING state.")
		
		player.smoothed_motion = Vector2(0, 1.0)
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("move_up")
		sender.action_down("sprint")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.SPRINTING, "Player should transition to SPRINTING state while holding sprint.")
		
		sender.action_up("sprint")
		sender.action_up("move_up")
		player.smoothed_motion = Vector2.ZERO
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should transition back to STANDING after releasing sprint.")
		
	func test_standing_to_crouching():
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should start in STANDING state.")
		
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("crouch")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.CROUCHING, "Player should transition to CROUCHING state while holding crouch.")
		
		sender.action_up("crouch")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should transition back to STANDING after releasing crouch.")
		
	func test_standing_to_attacking():
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should start in STANDING state.")
		
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("attack")
		await wait_physics_frames(2)
		sender.action_up("attack")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.ATTACKING, "Player should transition to ATTACKING state after attack action.")

class TestSprintingTransitions:
	extends FsmTestBase
	
	func test_sprinting_to_sliding():
		player.smoothed_motion = Vector2(0, 1.0)
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("move_up")
		sender.action_down("sprint")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.SPRINTING, "Player should be in SPRINTING state.")
		
		sender.action_down("crouch")
		await wait_physics_frames(2)
		sender.action_up("crouch")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.SLIDING, "Player should transition to SLIDING from sprint when crouch is pressed.")
		
		sender.action_up("sprint")
		sender.action_up("move_up")
		player.smoothed_motion = Vector2.ZERO

class TestPushingTransitions:
	extends FsmTestBase

	func test_standing_to_pushing_and_back():
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should start in STANDING state.")

		player.smoothed_motion = Vector2(0, 1.0)
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("move_up")

		# Walk forward until the player presses into the surrounding wall
		var frames_waited: int = 0
		while player.current_state != NodeStateMachine.States.PUSHING and frames_waited < 180:
			await wait_physics_frames(5)
			frames_waited += 5

		assert_eq(player.current_state, NodeStateMachine.States.PUSHING, "Player should transition to PUSHING when moving into a wall.")
		assert_true(player.is_pushing, "Player should be flagged as pushing.")

		await wait_physics_frames(30)
		assert_true(player.current_locomotion_node in ["PushingStart", "Pushing"], "Pushing animation should become active, got %s." % player.current_locomotion_node)

		sender.action_up("move_up")
		player.smoothed_motion = Vector2.ZERO
		await wait_physics_frames(5)

		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should transition back to STANDING when input stops.")
		assert_false(player.is_pushing, "Player should not be flagged as pushing.")

class TestAirborneTransitions:
	extends FsmTestBase
	
	func test_falling_to_standing_on_floor():
		player.state_machine.travel(player.current_state, NodeStateMachine.States.FALLING)
		await wait_physics_frames(2)
		
		# Position player slightly above ground so they quickly land
		player.global_position = Vector3(0, 0.2, 0)
		await wait_physics_frames(10)
		
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should transition to STANDING after landing on floor.")

	func test_jumping_to_climbing():
		# Start on floor
		player.global_position = Vector3(0, 0.1, 0)
		await wait_physics_frames(2)
		
		# Jump 1: STANDING -> JUMPING
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("jump")
		await wait_physics_frames(2)
		sender.action_up("jump")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.JUMPING, "Player should be jumping.")
		
		# Teleport player into air near walls while in JUMPING state
		player.global_position = Vector3(0, 2.0, 0)
		player.ledge_detection_horizontal.force_raycast_update()
		await wait_physics_frames(2)
		
		# Jump 2: JUMPING -> CLIMBING
		sender.action_down("jump")
		await wait_physics_frames(2)
		sender.action_up("jump")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.CLIMBING, "Player should transition to CLIMBING when jumping near wall while in air.")

class TestAttackingTransitions:
	extends FsmTestBase
	
	func test_attacking_timeout():
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("attack")
		await wait_physics_frames(2)
		sender.action_up("attack")
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.ATTACKING, "Player should be in ATTACKING state.")
		
		var attacking_state = player.state_machine.get_node("Attacking")
		attacking_state.boxing_inactivity_delay_remaining = 0.1
		
		await wait_seconds(0.2)
		await wait_physics_frames(2)
		
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should return to STANDING after attack timeout.")

class TestEquipmentInteractionTransitions:
	extends FsmTestBase

	func test_greatsword_logging_animation():
		var greatsword: Equipment = Equipment.new()
		greatsword.equipment_type = Equipment.EquipmentType.SWORD_2H
		greatsword.can_log = true
		root.add_child(greatsword)
		player.inventory.add_equipment(greatsword)

		player.locomotion_state.start("GreatSword")
		var greatsword_playback: AnimationNodeStateMachinePlayback = player.animation_tree.get(
				"parameters/LocomotionStateMachine/GreatSword/playback",
		)
		greatsword_playback.start("GreatSwordLocomotion")
		player.travel_locomotion("GreatSword/Logging")
		await wait_physics_frames(2)

		assert_true(player.is_logging, "GreatSword logging animation should become active.")

class TestEnableSettings:
	extends FsmTestBase

	func test_disabled_special_states_block_entry():
		var special_states: Array[NodeStateMachine.States] = [
			NodeStateMachine.States.FLYING,
			NodeStateMachine.States.PARAGLIDING,
			NodeStateMachine.States.RAGDOLLING,
		]
		for state: NodeStateMachine.States in special_states:
			player.state_machine.travel(player.current_state, state)
			assert_eq(
					player.current_state,
					NodeStateMachine.States.STANDING,
					"Disabled special state should not be entered.",
			)

	func test_enabled_flying_allows_entry():
		player.enable_flying = true
		player.state_machine.travel(player.current_state, NodeStateMachine.States.FLYING)
		assert_eq(player.current_state, NodeStateMachine.States.FLYING)

	func test_enabled_paraglider_allows_entry():
		player.enable_paraglider = true
		player.state_machine.travel(player.current_state, NodeStateMachine.States.PARAGLIDING)
		assert_eq(player.current_state, NodeStateMachine.States.PARAGLIDING)

	func test_enabled_ragdoll_allows_entry():
		player.enable_ragdoll = true
		player.state_machine.travel(player.current_state, NodeStateMachine.States.RAGDOLLING)
		assert_eq(player.current_state, NodeStateMachine.States.RAGDOLLING)

class TestPauseTransitions:
	extends FsmTestBase
	
	func test_no_ragdoll_when_pause_visible():
		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should start in STANDING state.")
		player.enable_ragdoll = true
		player.pause.show_menu()
		assert_true(player.is_paused, "Player should be paused.")
		assert_true(player.pause.visible, "Pause CanvasLayer should be visible.")
		
		player.state_machine.travel(player.current_state, NodeStateMachine.States.RAGDOLLING)
		await wait_physics_frames(2)
		
		assert_ne(player.current_state, NodeStateMachine.States.RAGDOLLING, "Player should not transition to RAGDOLLING when Pause CanvasLayer is visible.")

class TestSkateboardingTransitions:
	extends FsmTestBase

	func test_skateboarding_action_properties():
		var skateboarding_node: Skateboarding = player.state_machine.get_node("Skateboarding") as Skateboarding
		assert_not_null(skateboarding_node, "Skateboarding state node should exist.")
		assert_eq(skateboarding_node.keyboard_dismount_action, &"whistle")
		assert_eq(skateboarding_node.pad_dismount_action, &"whistle")
		assert_eq(skateboarding_node.keyboard_jump_action, &"jump")
		assert_eq(skateboarding_node.pad_jump_action, &"jump")

	func test_skateboarding_dismount_keyboard():
		player.state_machine.travel(player.current_state, NodeStateMachine.States.SKATEBOARDING)
		await wait_physics_frames(2)
		assert_eq(player.current_state, NodeStateMachine.States.SKATEBOARDING, "Player should be in SKATEBOARDING state.")

		player.controls.current_input_type = 0 # KEYBOARD_MOUSE
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("whistle")
		await wait_physics_frames(2)
		sender.action_up("whistle")
		await wait_physics_frames(2)

		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should transition to STANDING after whistle action.")

	func test_skateboarding_dismount_controller():
		player.state_machine.travel(player.current_state, NodeStateMachine.States.SKATEBOARDING)
		await wait_physics_frames(2)
		assert_eq(player.current_state, NodeStateMachine.States.SKATEBOARDING, "Player should be in SKATEBOARDING state.")

		player.controls.current_input_type = 1 # MICROSOFT controller
		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("whistle")
		await wait_physics_frames(2)
		sender.action_up("whistle")
		await wait_physics_frames(2)

		assert_eq(player.current_state, NodeStateMachine.States.STANDING, "Player should transition to STANDING after whistle action.")

	func test_held_object_reserves_dpad_down_while_skateboarding():
		player.state_machine.travel(player.current_state, NodeStateMachine.States.SKATEBOARDING)
		await wait_physics_frames(2)

		var held_body: RigidBody3D = RigidBody3D.new()
		root.add_child(held_body)
		player.held_object._pickup_rigidbody(held_body)

		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("whistle")
		await wait_physics_frames(2)
		sender.action_up("whistle")
		await wait_physics_frames(2)

		assert_eq(
			player.current_state,
			NodeStateMachine.States.SKATEBOARDING,
			"Held object controls should reserve D-pad Down from skateboard dismount.",
		)
		player.held_object.drop_held_rigidbody()

	func test_move_down_does_not_dismount():
		player.state_machine.travel(player.current_state, NodeStateMachine.States.SKATEBOARDING)
		await wait_physics_frames(2)
		assert_eq(player.current_state, NodeStateMachine.States.SKATEBOARDING, "Player should be in SKATEBOARDING state.")

		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("move_down")
		await wait_physics_frames(2)
		sender.action_up("move_down")
		await wait_physics_frames(2)

		assert_eq(player.current_state, NodeStateMachine.States.SKATEBOARDING, "Player should remain in SKATEBOARDING state when move_down is pressed.")

	func test_skateboarding_contextual_controls():
		var skateboarding_node: Skateboarding = player.state_machine.get_node("Skateboarding") as Skateboarding
		var kb_controls = skateboarding_node.get_contextual_controls(0)
		assert_eq(kb_controls.get(player.controls.key_k_label), "Dismount")
		assert_eq(kb_controls.get(player.controls.joypad_button_1_label), "Fast Push")

		var pad_controls = skateboarding_node.get_contextual_controls(1)
		assert_eq(pad_controls.get(player.controls.joypad_button_12_label), "Dismount")
		assert_eq(pad_controls.get(player.controls.joypad_button_1_label), "Fast Push")
		assert_false(pad_controls.has(player.controls.joypad_button_7_label))

	func test_held_object_contextual_controls_restore_skateboarding_labels():
		player.state_machine.travel(player.current_state, NodeStateMachine.States.SKATEBOARDING)
		player.controls.current_input_type = player.controls.InputType.KEYBOARD_MOUSE

		var held_body: RigidBody3D = RigidBody3D.new()
		root.add_child(held_body)
		player.held_object._pickup_rigidbody(held_body)
		assert_eq(player.controls.key_i_label.text, "Farther")
		assert_eq(player.controls.key_k_label.text, "Closer")
		assert_eq(player.controls.key_j_label.text, "")
		assert_eq(player.controls.key_l_label.text, "")
		assert_eq(player.controls.joypad_button_10_label.text, "Rotate")
		assert_eq(player.controls.joypad_axis_5_plus_label.text, "Throw")

		var sender = InputSender.new(Input)
		sender.set_auto_flush_input(true)
		sender.action_down("throw")
		await wait_physics_frames(1)
		assert_eq(player.controls.key_i_label.text, "Rotate Up")
		assert_eq(player.controls.key_j_label.text, "Rotate Left")
		assert_eq(player.controls.key_k_label.text, "Rotate Down")
		assert_eq(player.controls.key_l_label.text, "Rotate Right")
		sender.action_up("throw")
		await wait_physics_frames(1)
		assert_eq(player.controls.key_j_label.text, "")
		assert_eq(player.controls.key_l_label.text, "")

		player.controls.current_input_type = player.controls.InputType.MICROSOFT
		assert_eq(player.controls.joypad_button_11_label.text, "Farther")
		assert_eq(player.controls.joypad_button_12_label.text, "Closer")
		assert_eq(player.controls.joypad_button_13_label.text, "")
		assert_eq(player.controls.joypad_button_14_label.text, "")
		sender.action_down("throw")
		await wait_physics_frames(1)
		assert_eq(player.controls.joypad_button_11_label.text, "Rotate Up")
		assert_eq(player.controls.joypad_button_12_label.text, "Rotate Down")
		assert_eq(player.controls.joypad_button_13_label.text, "Rotate Left")
		assert_eq(player.controls.joypad_button_14_label.text, "Rotate Right")
		sender.action_up("throw")
		await wait_physics_frames(1)

		player.held_object.drop_held_rigidbody()
		assert_eq(player.controls.joypad_button_12_label.text, "Dismount")
		assert_eq(player.controls.joypad_button_1_label.text, "Fast Push")
