extends GutTest

## Purpose: To test holding last/next weapon to open RadialMenu in inventory.

class TestRadialMenuHold:
	extends IntegrationTestBase

	var PlayerScene = load("res://addons/3d_player_controller/scenes/player.tscn")
	var root: Node3D = null
	var player_instance: Player = null

	func before_each() -> void:
		root = Node3D.new()
		add_child_autofree(root)
		player_instance = PlayerScene.instantiate() as Player
		root.add_child(player_instance)
		await wait_physics_frames(2)

	func after_each() -> void:
		Input.action_release("last_weapon")
		Input.action_release("next_weapon")
		if is_instance_valid(root):
			root.free()
			root = null
			player_instance = null

	func test_radial_menu_is_menu_held_returns_true_for_last_or_next_weapon():
		var player = player_instance
		var radial_menu = player.inventory.get_node("RadialMenu") as RadialMenu
		assert_not_null(radial_menu, "RadialMenu should exist on inventory")
		
		# Test last_weapon
		Input.action_press("last_weapon")
		assert_true(radial_menu.is_menu_held(), "is_menu_held should return true when last_weapon is pressed")
		Input.action_release("last_weapon")

		# Test next_weapon
		Input.action_press("next_weapon")
		assert_true(radial_menu.is_menu_held(), "is_menu_held should return true when next_weapon is pressed")
		Input.action_release("next_weapon")
