extends GutTest

## Purpose: the Flashlight holds a Stalker still while its beam is on it, without undoing a slow the enemy is under;
## only the Player's authority switches it; it runs its physics only while on; and the battery runs it dark.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/npc/enemy_npc.tscn")

var player: Player
var enemy: EnemyNpc
var torch: Flashlight


func before_each() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(40.0, 1.0, 40.0)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	enemy = ENEMY_SCENE.instantiate()
	enemy.position = Vector3(0.0, 0.0, -8.0)
	enemy.add_to_group(&"Stalkers")
	root.add_child(enemy)
	torch = Flashlight.new()
	torch.player = player
	torch.spot_angle = 30.0
	torch.position = Vector3(0.0, 1.5, 0.0)
	player.add_child(torch)
	await wait_physics_frames(3)
	torch.look_at(Focus.get_focus_target_position(enemy))


func _press() -> void:
	var press := InputEventAction.new()
	press.action = torch.action
	press.pressed = true
	torch._input(press)


func test_the_beam_holds_a_stalker_still_and_a_slow_under_it_outlasts_the_beam() -> void:
	assert_false(torch.is_physics_processing(), "Off, the torch runs no physics")
	assert_false(torch.visible)
	torch._switch(true)
	assert_true(torch.is_on)
	assert_true(torch.visible)
	assert_true(torch.is_physics_processing(), "On, it drains and looks for what it lights")
	await wait_physics_frames(2)
	assert_true(torch.lights(enemy), "The enemy stands in the beam")
	assert_true(enemy.frozen, "so it is held still")
	assert_eq(enemy.movement_scale, 0.0)
	enemy.slow(0.5, 5.0) # a frostbolt lands meanwhile
	assert_eq(enemy.movement_scale, 0.0, "Still held while lit")
	torch._switch(false)
	assert_false(enemy.frozen, "Off, the beam lets go")
	assert_almost_eq(enemy.movement_scale, 0.5, 0.001, "and the frostbolt's slow is still there, not reset to full speed")
	assert_false(torch.is_physics_processing())


func test_only_the_owner_switches_it_and_the_battery_runs_it_dark() -> void:
	_press()
	assert_true(torch.is_on, "The owner's key turns it on")
	_press()
	assert_false(torch.is_on, "and off")
	torch.set_multiplayer_authority(7) # somebody else's torch, as a puppet's is
	_press()
	assert_false(torch.is_on, "A copy that is not the Player's authority ignores the key")
	torch.set_multiplayer_authority(1)
	watch_signals(torch)
	torch.battery = 0.05
	torch._switch(true)
	await wait_seconds(0.2)
	assert_false(torch.is_on, "An empty battery puts it out")
	assert_signal_emitted(torch, "went_dark")
	assert_false(enemy.frozen, "and lets go of what it held")
