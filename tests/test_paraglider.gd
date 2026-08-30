extends GutTest

## Purpose: To test the Paraglider scene and its Trail3D contrail nodes.

class TestParagliderContrails:
	extends GutTest

	var paraglider_scene = preload("res://scenes/paraglider.tscn")
	var paraglider: Node3D

	func before_each() -> void:
		paraglider = paraglider_scene.instantiate()
		add_child_autofree(paraglider)

	func test_paraglider_instantiation() -> void:
		assert_not_null(paraglider, "Paraglider should instantiate successfully.")
		var left_wing = paraglider.get_node_or_null("LeftWing")
		var right_wing = paraglider.get_node_or_null("RightWing")
		assert_not_null(left_wing, "LeftWing node should exist.")
		assert_not_null(right_wing, "RightWing node should exist.")
		assert_is(left_wing, Trail3D, "LeftWing should be a Trail3D node.")
		assert_is(right_wing, Trail3D, "RightWing should be a Trail3D node.")

	func test_trail_properties_configured() -> void:
		var left_wing: Trail3D = paraglider.get_node("LeftWing") as Trail3D
		var right_wing: Trail3D = paraglider.get_node("RightWing") as Trail3D
		
		assert_false(left_wing.emitting, "LeftWing trail should not emit by default.")
		assert_false(right_wing.emitting, "RightWing trail should not emit by default.")
		assert_eq(left_wing.width, 0.05, "LeftWing width should match configuration.")
		assert_eq(right_wing.width, 0.05, "RightWing width should match configuration.")
		assert_eq(left_wing.lifetime, 1.0, "LeftWing lifetime should be 1.0.")
		assert_eq(right_wing.lifetime, 1.0, "RightWing lifetime should be 1.0.")
		assert_eq(left_wing.min_section_length, 0.06, "LeftWing min section length should be 0.06.")
		assert_not_null(left_wing.color_gradient, "LeftWing should have a color gradient.")
		assert_not_null(left_wing.width_curve, "LeftWing should have a width curve.")

	func test_paraglider_state_toggles_trail_emitting() -> void:
		var left_wing: Trail3D = paraglider.get_node("LeftWing") as Trail3D
		var right_wing: Trail3D = paraglider.get_node("RightWing") as Trail3D

		# Mock a player object
		var mock_player = Node.new()
		mock_player.set_script(load("res://addons/3d_player_controller/scripts/player.gd"))
		add_child_autofree(mock_player)
		paraglider.player = mock_player

		# Simulate paragliding started
		mock_player.is_paragliding = true
		paraglider.visible = false
		paraglider._physics_process(0.016)

		assert_true(paraglider.visible, "Paraglider should be visible when paragliding.")
		assert_true(left_wing.emitting, "LeftWing trail should emit when paragliding.")
		assert_true(right_wing.emitting, "RightWing trail should emit when paragliding.")

		# Simulate paragliding stopped
		mock_player.is_paragliding = false
		paraglider._physics_process(0.016)

		assert_false(paraglider.visible, "Paraglider should be hidden when not paragliding.")
		assert_false(left_wing.emitting, "LeftWing trail should not emit when not paragliding.")
		assert_false(right_wing.emitting, "RightWing trail should not emit when not paragliding.")
