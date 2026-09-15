extends GutTest

## Purpose: The survival demo is a playable slice: hunger and thirst drain and an empty one eats health, berries
## and the stream fill them, a bush gives berries to bare hands but a tree needs the axe and a boulder the
## pickaxe, the workbench turns wood and stone into the axe, the pickaxe and the shelter, and the recipes are
## the run.

const DEMO_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/demo/survival/survival_demo.tscn")
const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/survival_shelter.tres")
const WOOD: Item = preload("res://addons/3d_player_controller/resources/items/wood.tres")
const STONE: Item = preload("res://addons/3d_player_controller/resources/items/stone.tres")
const BERRIES: Item = preload("res://addons/3d_player_controller/resources/items/berries.tres")
const RECIPE_AXE: Recipe = preload("res://addons/3d_player_controller/resources/recipes/stone_axe.tres")
const RECIPE_PICKAXE: Recipe = preload("res://addons/3d_player_controller/resources/recipes/stone_pickaxe.tres")
const RECIPE_SHELTER: Recipe = preload("res://addons/3d_player_controller/resources/recipes/shelter.tres")

var demo: Node3D
var player: Player
var vitals: Vitals


func before_each() -> void:
	demo = DEMO_SCENE.instantiate()
	add_child_autofree(demo)
	await wait_physics_frames(3)
	player = demo.player
	vitals = demo.vitals


func test_hunger_and_thirst_drain_and_an_empty_one_eats_health() -> void:
	assert_true(player.quest_log.is_active(QUEST))
	var hunger: float = vitals.hunger
	await wait_seconds(0.5)
	assert_lt(vitals.hunger, hunger, "Draining")
	assert_lt(vitals.thirst, vitals.hunger, "Thirst faster")
	vitals.thirst = 0.0
	var health: float = player.health.health
	await wait_seconds(0.5)
	assert_lt(player.health.health, health, "Parched, it hurts")
	vitals.eat(30.0)
	vitals.drink(40.0)
	assert_almost_eq(vitals.thirst, 40.0 - vitals.thirst_drain * 0.0, 2.0, "A drink puts forty back")


func test_berries_and_the_stream_feed_the_vitals() -> void:
	vitals.hunger = 20.0
	vitals.thirst = 20.0
	player.inventory.add_item(BERRIES, 1)
	player.inventory.use_item(BERRIES, 1)
	assert_almost_eq(vitals.hunger, 50.0, 1.0, "Thirty from the berries")
	var stream: WaterSource = demo.get_node("Stream/Water")
	stream.drink(player)
	assert_almost_eq(vitals.thirst, 60.0, 1.0, "Forty from the stream")


func test_a_bush_gives_to_bare_hands_but_a_tree_needs_the_axe() -> void:
	var bush: Harvestable = demo.get_node("Woods/Bush1")
	bush.register_weapon_hit(player, player)
	assert_eq(player.inventory.count_of(BERRIES), 2, "One punch, two berries")
	var tree: Harvestable = demo.get_node("Woods/Tree1")
	tree.register_weapon_hit(player, player)
	tree.register_weapon_hit(player, player)
	tree.register_weapon_hit(player, player)
	assert_eq(player.inventory.count_of(WOOD), 0, "Bare hands do nothing to a tree")
	player.inventory.add_item(WOOD, 3)
	player.inventory.add_item(STONE, 2)
	var station: CraftingStation = demo.station
	assert_true(station.craft(player, RECIPE_AXE), "Three wood and two stone make the axe")
	assert_eq(player.inventory.count_of(WOOD), 0, "Spent")
	var axe: Equipment = player.inventory.get_all_weapons()[0]
	assert_true(axe.can_log, "And it is in hand")
	for i: int in 3:
		tree.register_weapon_hit(axe, axe)
	assert_eq(player.inventory.count_of(WOOD), 3, "Three swings of the axe: three logs")
	for i: int in 6:
		tree.register_weapon_hit(axe, axe)
	assert_true(tree.is_spent, "Three yields and the tree is down")
	assert_false(tree.visible)


func test_the_workbench_refuses_what_the_bag_cannot_pay_and_the_shelter_ends_the_run() -> void:
	var station: CraftingStation = demo.station
	assert_false(station.craft(player, RECIPE_PICKAXE), "Nothing in the bag")
	player.inventory.add_item(WOOD, 13)
	player.inventory.add_item(STONE, 9)
	assert_true(station.craft(player, RECIPE_AXE))
	assert_true(station.craft(player, RECIPE_PICKAXE))
	assert_eq(player.inventory.get_all_weapons().size(), 2, "Both tools are carried: the pickaxe is a two-handed axe, so the one-handed slot is not in its way")
	assert_true(player.quest_log.is_objective_done(QUEST, &"craft_axe"))
	assert_true(player.quest_log.is_objective_done(QUEST, &"craft_pickaxe"))
	assert_true(station.craft(player, RECIPE_SHELTER))
	assert_true(demo.shelter_built)
	assert_true(demo.shelter.visible, "A roof in the world")
	assert_true(player.quest_log.is_complete(QUEST))
	assert_eq(player.inventory.count_of(WOOD), 0)


func test_the_crafting_screen_lists_the_recipes_and_crafts_by_index() -> void:
	var screen: CraftingScreen = demo.get_node("CraftingScreen")
	var station: CraftingStation = demo.station
	assert_true(station.open(player))
	assert_true(screen.visible)
	assert_true(player.is_paused, "A menu")
	assert_eq(screen._buttons.size(), 3)
	assert_true(screen._buttons[0].disabled, "Greyed with an empty bag")
	player.inventory.add_item(WOOD, 3)
	player.inventory.add_item(STONE, 2)
	screen._refresh()
	assert_false(screen._buttons[0].disabled)
	assert_true(screen.craft_index(0))
	assert_true(screen._buttons[0].disabled, "Paid, and greyed again")
	screen.hide_menu()
	assert_false(screen.visible)
	assert_false(player.is_paused)
