extends GutTest

## Purpose: Abilities work the World of Warcraft way on the Zelda-style controls: a tap of "ability"
## casts the picked ability, a hold opens the wheel to pick another, timed casts run a cast bar that any
## movement interrupts, toggles such as Stealth end on attack, and cooldowns gate recasts.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const STEALTH: Ability = preload("res://addons/3d_player_controller/resources/abilities/stealth.tres")
const HEAL: Ability = preload("res://addons/3d_player_controller/resources/abilities/heal.tres")

var player: Player
var abilities: Abilities
var stealth: StealthAbility
var heal: HealAbility
var sender


func before_each() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(20.0, 1.0, 20.0)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	player.enable_stamina = true
	abilities = player.abilities
	stealth = STEALTH.duplicate()
	heal = HEAL.duplicate()
	abilities.abilities = [stealth, heal]
	abilities.active_ability = stealth
	sender = InputSender.new(Input)
	sender.set_auto_flush_input(true)
	await wait_physics_frames(20)


func after_each() -> void:
	sender.release_all()
	sender.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_player_scene_ships_with_stealth_and_heal_picked_first() -> void:
	var fresh: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(fresh)
	await wait_physics_frames(2)
	assert_eq(fresh.abilities.abilities.size(), 2)
	assert_eq(fresh.abilities.active_ability, fresh.abilities.abilities[0])
	assert_eq(fresh.controls.joypad_button_9_label.text, "Stealth", "The left shoulder label names the picked ability")


func test_wheel_lists_abilities_and_picking_does_not_cast() -> void:
	var items: Array[Dictionary] = abilities.get_wheel_items()
	assert_eq(items.size(), 2)
	assert_eq(items[1]["display_name"], "Heal")
	assert_eq(items[1]["item"], heal)
	assert_true(abilities.radial_menu.custom_item_is_equipped.call(items[0], 0), "The picked ability draws as equipped")
	abilities.radial_menu.custom_item_selected.call(items[1], 1)
	assert_eq(abilities.active_ability, heal)
	assert_null(abilities.casting, "Picking from the wheel only changes the active ability")
	assert_eq(player.controls.joypad_button_9_label.text, "Heal")


func test_holding_ability_opens_the_wheel_and_a_tap_casts() -> void:
	sender.action_down("ability")
	await wait_seconds(0.3)
	assert_true(abilities.radial_menu.is_open(), "Holding the ability action opens the wheel")
	assert_false(player.is_stealthed)
	sender.action_up("ability")
	await wait_physics_frames(2)
	assert_false(abilities.radial_menu.is_open())
	assert_false(player.is_stealthed, "Releasing after a hold is not a cast")

	sender.action_down("ability")
	await wait_physics_frames(1)
	sender.action_up("ability")
	await wait_physics_frames(1)
	assert_true(player.is_stealthed, "A tap casts the picked ability")


func test_stealth_toggles_fades_the_model_and_costs_stamina() -> void:
	watch_signals(abilities)
	var before: float = player.stamina.stamina
	abilities.cast(stealth)
	assert_true(player.is_stealthed)
	assert_signal_emitted_with_parameters(abilities, "ability_activated", [stealth])
	assert_almost_eq(player.stamina.stamina, before - stealth.stamina_cost, 0.01)
	for mesh: MeshInstance3D in player.skeleton.find_children("*", "MeshInstance3D"):
		assert_almost_eq(mesh.transparency, player.stealth_transparency, 0.001)

	abilities.cast(stealth)
	assert_false(player.is_stealthed, "Casting an active toggle ends it")
	assert_signal_emitted_with_parameters(abilities, "ability_deactivated", [stealth])
	for mesh: MeshInstance3D in player.skeleton.find_children("*", "MeshInstance3D"):
		assert_almost_eq(mesh.transparency, 0.0, 0.001)


func test_attacking_ends_stealth() -> void:
	abilities.cast(stealth)
	player.locomotion_node_changed.emit("ShortHeadJab")
	assert_false(player.is_stealthed, "A melee swing breaks stealth")
	assert_true(abilities.active_toggles.is_empty())


func test_heal_casts_over_time_and_restores_stamina() -> void:
	watch_signals(abilities)
	player.stamina.stamina = 20.0
	heal.cast_time = 0.3
	abilities.cast(heal)
	assert_eq(abilities.casting, heal)
	assert_true(player.controls.cast_bar.visible, "A timed cast shows the cast bar")
	assert_signal_emitted(abilities, "cast_started")
	assert_almost_eq(player.stamina.stamina, 20.0, 5.0, "Nothing lands until the cast finishes")
	await wait_seconds(0.5)
	assert_null(abilities.casting)
	assert_false(player.controls.cast_bar.visible)
	assert_gt(player.stamina.stamina, 60.0, "The heal restores stamina once the cast lands")
	assert_signal_emitted_with_parameters(abilities, "ability_activated", [heal])


func test_heal_is_refused_at_full_stamina_without_spending_its_cooldown() -> void:
	heal.cast_time = 0.0
	abilities.cast(heal)
	assert_true(abilities.is_ready(heal), "A refused cast spends no cooldown")


func test_moving_interrupts_a_cast() -> void:
	watch_signals(abilities)
	player.stamina.stamina = 20.0
	heal.cast_time = 1.0
	abilities.cast(heal)
	player.locomotion_node_changed.emit("Walking")
	assert_null(abilities.casting)
	assert_signal_emitted_with_parameters(abilities, "cast_interrupted", [heal])
	assert_false(player.controls.cast_bar.visible)
	assert_true(abilities.cast_timer.is_stopped())
	assert_almost_eq(player.stamina.stamina, 20.0, 5.0, "An interrupted heal lands nothing")


func test_cooldown_gates_recasts() -> void:
	stealth.cooldown = 0.2
	abilities.cast(stealth)
	abilities.cast(stealth)
	assert_false(player.is_stealthed)
	assert_false(abilities.is_ready(stealth))
	assert_gt(abilities.get_cooldown_remaining(stealth), 0.0)
	abilities.cast(stealth)
	assert_false(player.is_stealthed, "The cooldown blocks the recast")
	await wait_seconds(0.3)
	assert_true(abilities.is_ready(stealth))
	abilities.cast(stealth)
	assert_true(player.is_stealthed)


func test_a_cast_needs_the_stamina_cost() -> void:
	player.stamina.stamina = 5.0
	abilities.cast(stealth)
	assert_false(player.is_stealthed, "Stealth costs more stamina than the Player has")


## A PackedScene whose root is a plain Node3D, standing in for a particle effect.
func _make_vfx() -> PackedScene:
	var scene := PackedScene.new()
	scene.pack(Node3D.new())
	return scene


func test_channeling_fx_run_for_the_cast_and_stop_when_interrupted() -> void:
	player.stamina.stamina = 20.0
	heal.cast_time = 1.0
	heal.channeling_vfx = _make_vfx()
	heal.channeling_sfx = AudioStreamGenerator.new()
	abilities.cast(heal)
	await wait_physics_frames(1)
	assert_eq(abilities.fx_root.get_child_count(), 4, "The channeling VFX joins the three audio players")
	assert_true(abilities.channeling_audio.playing)
	assert_eq(abilities.channeling_audio.stream, heal.channeling_sfx)
	abilities.interrupt_cast()
	await wait_physics_frames(1)
	assert_eq(abilities.fx_root.get_child_count(), 3, "Interrupting frees the channeling VFX")
	assert_false(abilities.channeling_audio.playing)


func test_casting_and_impact_fx_play_when_the_effect_lands() -> void:
	player.stamina.stamina = 20.0
	heal.cast_time = 0.0
	heal.casting_vfx = _make_vfx()
	heal.impact_vfx = _make_vfx()
	heal.casting_sfx = AudioStreamGenerator.new()
	heal.impact_sfx = AudioStreamGenerator.new()
	heal.fx_lifetime = 0.2
	abilities.cast(heal)
	await wait_physics_frames(1)
	assert_eq(abilities.fx_root.get_child_count(), 5, "Casting and impact VFX are instanced")
	assert_eq(abilities.casting_audio.stream, heal.casting_sfx)
	assert_eq(abilities.impact_audio.stream, heal.impact_sfx)
	assert_true(abilities.casting_audio.playing)
	assert_true(abilities.impact_audio.playing)
	await wait_seconds(0.4)
	assert_eq(abilities.fx_root.get_child_count(), 3, "One-shot VFX free themselves after fx_lifetime")


func test_impact_lands_where_the_ability_says() -> void:
	var ranged := RangedAbility.new()
	ranged.impact_vfx = _make_vfx()
	abilities.abilities.append(ranged)
	abilities.cast(ranged)
	await wait_physics_frames(1)
	var vfx: Node3D = abilities.fx_root.get_child(3)
	assert_almost_eq(vfx.global_position, player.global_position + Vector3(0.0, 0.0, -5.0), Vector3.ONE * 0.01)


class RangedAbility extends Ability:
	func get_impact_position(player: Player) -> Vector3:
		return player.global_position + Vector3(0.0, 0.0, -5.0)


## A bolt aimed at a fixed dummy, recording every impact target.
class BoltAbility extends Ability:
	var dummy: Node3D
	var hits: Array[Node3D] = []
	func _init() -> void:
		projectile_speed = 10.0
	func get_target(_player: Player) -> Node3D:
		return dummy
	func impact(_player: Player, target: Node3D) -> void:
		hits.append(target)


func _make_bolt(at: Vector3) -> BoltAbility:
	var bolt := BoltAbility.new()
	bolt.dummy = Node3D.new()
	bolt.dummy.position = at
	player.get_parent().add_child(bolt.dummy)
	bolt.casting_vfx = _make_vfx()
	bolt.impact_vfx = _make_vfx()
	bolt.casting_sfx = AudioStreamGenerator.new()
	abilities.abilities.append(bolt)
	return bolt


func test_projectile_spell_flies_the_casting_fx_to_the_target_and_lands_impact_on_arrival() -> void:
	var bolt := _make_bolt(Vector3(4.0, 0.0, 0.0))
	abilities.cast(bolt)
	var projectile: SpellProjectile = abilities.fx_root.get_child(3)
	assert_almost_eq(projectile.global_position.y, player.global_position.y + abilities.PROJECTILE_HEIGHT, 0.01, "The bolt leaves at chest height")
	await wait_physics_frames(1)
	assert_true(projectile.homing, "Spell projectiles home by default")
	assert_eq(projectile.get_child_count(), 2, "The bolt carries the casting VFX next to its audio player")
	assert_eq(projectile.audio.stream, bolt.casting_sfx)
	assert_true(bolt.hits.is_empty(), "Nothing lands until the bolt arrives")
	bolt.dummy.position = Vector3(0.0, 0.0, 4.0)
	await wait_seconds(0.8)
	assert_eq(bolt.hits, [bolt.dummy] as Array[Node3D], "Impact lands on the target when the bolt arrives")
	assert_false(is_instance_valid(projectile), "The bolt frees itself on arrival")
	var impact_vfx: Node3D = abilities.fx_root.get_child(3)
	assert_lt(impact_vfx.global_position.distance_to(bolt.dummy.global_position), 1.5, "Impact VFX spawn where the moved target ended up")


func test_non_homing_bolt_flies_to_where_the_target_was() -> void:
	var bolt := _make_bolt(Vector3(4.0, 0.0, 0.0))
	bolt.projectile_homing = false
	abilities.cast(bolt)
	await wait_physics_frames(1)
	bolt.dummy.position = Vector3(0.0, 0.0, 4.0)
	await wait_seconds(0.8)
	assert_eq(bolt.hits.size(), 1)
	assert_lt(abilities.fx_root.get_child(3).global_position.distance_to(Vector3(4.0, 0.0, 0.0)), 1.5, "Impact lands at the original aim point")


func test_focus_mode_falls_back_to_the_aim_point_without_a_lock() -> void:
	var aimed := Ability.new()
	aimed.target_mode = Ability.Target.FOCUS
	assert_null(aimed.get_target(player))
	var at: Vector3 = aimed.get_impact_position(player)
	assert_gt(at.distance_to(player.global_position), 5.0, "With nothing locked on the impact lands along the aim ray")


func test_puppets_fade_when_the_replicated_flag_arrives() -> void:
	var puppet: Player = PLAYER_SCENE.instantiate()
	puppet.name = "999"
	add_child_autofree(puppet)
	await wait_physics_frames(2)
	assert_false(puppet.is_multiplayer_authority())
	assert_false(puppet.abilities.is_processing_unhandled_input(), "Only the authority casts")
	puppet.is_stealthed = true
	for mesh: MeshInstance3D in puppet.skeleton.find_children("*", "MeshInstance3D"):
		assert_almost_eq(mesh.transparency, puppet.stealth_transparency, 0.001)
