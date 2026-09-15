extends GutTest

## Purpose: The Zelda demo is a playable slice, not a diorama: the village holds a sword, a shield and a bow to pick
## up, coins lie in the grass, the elder's errand starts from his dialogue and counts the raiders and the chest,
## the chest opens on Action and hands out its coins, a potion drunk heals, and the HUD shows every button with
## the contextual words a pickup or the chest put on the Action button.

const DEMO_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/demo/zelda/zelda_demo.tscn")
const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/zelda_camp.tres")
const COIN: Item = preload("res://addons/3d_player_controller/resources/items/gold_coin.tres")
const POTION: Item = preload("res://addons/3d_player_controller/resources/items/red_potion.tres")

var demo: Node3D
var player: Player


func before_each() -> void:
	demo = DEMO_SCENE.instantiate()
	add_child_autofree(demo)
	await wait_physics_frames(3)
	player = demo.player
	player.dialogue_screen.characters_per_second = 0.0


func test_the_demo_sets_the_player_up_for_zelda() -> void:
	assert_eq(player.control_scheme, PlayerControls.ControlScheme.ZELDA)
	assert_true(player.enable_stamina)
	assert_true(player.enable_paraglider)
	assert_true(player.lock_on_enabled())
	assert_false(player.controls.contextual_only, "The whole HUD is on screen in a demo")
	assert_true(player.controls.joypad_button_0.visible)
	assert_true(demo.get_node("Village/BronzeSword") is Equipment)
	assert_true(demo.get_node("Village/HuntersBow") is Bow)
	assert_eq(demo.get_node("Camp/Raiders").get_child_count(), 3)


func test_walking_over_the_sword_equips_it() -> void:
	var sword: Equipment = demo.get_node("Village/BronzeSword")
	player.warp_to(Transform3D(Basis(), sword.global_position))
	await wait_physics_frames(3)
	assert_true(player.equipped_sword_1h, "The sword is in hand")
	assert_true(player.inventory.can_player_attack)


func test_the_elders_errand_counts_raiders_and_the_chest() -> void:
	var elder: TalkingNpc = demo.get_node("Village/Elder")
	var log: QuestLog = player.quest_log
	assert_true(elder.talk(player))
	await wait_process_frames(1)
	player.dialogue_screen._choice_buttons[0].pressed.emit()
	assert_true(log.is_active(QUEST), "Accepting starts the errand")
	player.dialogue_screen.end()
	for raider: EnemyNpc in demo.get_node("Camp/Raiders").get_children():
		raider.take_hit(500.0, player.global_position)
	await wait_physics_frames(2)
	assert_true(log.is_objective_done(QUEST, &"defeat_raider"), "Three raiders down")
	var chest: TreasureChest = demo.get_node("Shrine/TreasureChest")
	assert_true(chest.open(player))
	assert_true(chest.is_open)
	assert_eq(player.inventory.count_of(COIN), 25, "The chest's coins are in the bag")
	assert_true(log.is_complete(QUEST))
	assert_eq(player.inventory.count_of(POTION), 2, "The elder pays in potions")
	assert_false(chest.open(player), "A chest opens once")


func test_the_chest_offers_open_and_a_coin_offers_pick_up_on_the_action_button() -> void:
	var chest: TreasureChest = demo.get_node("Shrine/TreasureChest")
	player.warp_to(Transform3D(Basis(), chest.global_position + Vector3(0.0, 0.0, 1.2)))
	await wait_physics_frames(3)
	assert_eq(player.controls.joypad_button_0_label.text, "Open", "Walking up to the chest offers Open")
	assert_true(player.controls.is_label_contextual(player.controls.joypad_button_0_label))
	var press: InputEventAction = InputEventAction.new()
	press.action = &"action"
	press.pressed = true
	Input.parse_input_event(press)
	await wait_physics_frames(2)
	var release: InputEventAction = InputEventAction.new()
	release.action = &"action"
	release.pressed = false
	Input.parse_input_event(release)
	assert_true(chest.is_open, "Action opens it from there")
	assert_eq(player.controls.joypad_button_0_label.text, "Action", "And the word is given back")
	var coin: ItemPickup = demo.get_node("Coins/Coin1")
	player.warp_to(Transform3D(Basis(), coin.global_position))
	await wait_physics_frames(3)
	assert_eq(player.controls.joypad_button_0_label.text, "Pick Up")


func test_a_potion_drunk_heals() -> void:
	player.health.health = 30.0
	player.inventory.add_item(POTION, 1)
	player.inventory.use_item(POTION, 1)
	assert_eq(player.health.health, 70.0)
	assert_eq(player.inventory.count_of(POTION), 0)


func test_the_pond_is_swimmable_and_the_cliff_has_a_checkpoint() -> void:
	player.warp_to(Transform3D(Basis(), Vector3(0.0, 0.0, 20.0)))
	await wait_physics_frames(8)
	assert_eq(player.current_state, NodeStateMachine.States.SWIMMING, "Into the pond, into the water")
	assert_true(demo.get_node("Cliff/CliffCheckpoint") is Checkpoint)
	assert_true(demo.get_node("SaveGame") is SaveGame)
