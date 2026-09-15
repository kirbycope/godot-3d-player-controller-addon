extends DemoScene
## The survival style: hunger and thirst that drain and hurt at empty, branches and loose stones to comb off the
## beach, a workbench with recipes, a stone axe that fells trees for wood, a pickaxe that breaks boulders for
## stone, berry bushes to punch and a stream to drink from, and a shelter to build before you starve.

const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/survival_shelter.tres")
const BERRIES: Item = preload("res://addons/3d_player_controller/resources/items/berries.tres")
const SHELTER_KIT: Item = preload("res://addons/3d_player_controller/resources/items/shelter_kit.tres")
const RECIPE_AXE: Recipe = preload("res://addons/3d_player_controller/resources/recipes/stone_axe.tres")
const RECIPE_PICKAXE: Recipe = preload("res://addons/3d_player_controller/resources/recipes/stone_pickaxe.tres")
const RECIPE_SHELTER: Recipe = preload("res://addons/3d_player_controller/resources/recipes/shelter.tres")
const BERRIES_FEED: float = 30.0

@export var vitals: Vitals
@export var station: CraftingStation
@export var stream: WaterSource
@export var shelter: Node3D ## Shown once built.
@export var hunger_bar: ProgressBar
@export var thirst_bar: ProgressBar

var shelter_built: bool = false


func setup_player(target: Player) -> void:
	target.enable_stamina = false
	target.inventory.item_used.connect(_on_item_used)
	vitals.vitals_changed.connect(_on_vitals_changed)
	_on_vitals_changed(vitals.hunger, vitals.thirst, vitals.capacity)
	station.crafted.connect(_on_crafted)
	if target.quest_log:
		target.quest_log.start(QUEST)


func _on_item_used(item: Item, count: int) -> void:
	if item == BERRIES:
		vitals.eat(BERRIES_FEED * count)


func _on_vitals_changed(hunger: float, thirst: float, capacity: float) -> void:
	if hunger_bar:
		hunger_bar.value = hunger / maxf(capacity, 0.01)
	if thirst_bar:
		thirst_bar.value = thirst / maxf(capacity, 0.01)


## The recipes are the errand: the axe, the pickaxe, then the shelter, which is a roof in the world rather than
## a thing in the bag.
func _on_crafted(by: Player, recipe: Recipe) -> void:
	if by == null or by.quest_log == null:
		return
	if recipe == RECIPE_AXE:
		by.quest_log.progress(&"craft_axe")
	elif recipe == RECIPE_PICKAXE:
		by.quest_log.progress(&"craft_pickaxe")
	elif recipe == RECIPE_SHELTER:
		by.inventory.remove_item(SHELTER_KIT, by.inventory.count_of(SHELTER_KIT))
		shelter_built = true
		shelter.visible = true
		by.quest_log.progress(&"build_shelter")


## The recording: the beach combed, the bench and the axe, berries eaten, a drink, three trees, the pickaxe, a
## boulder, and the shelter raised.
func build_autopilot(pilot: DemoAutopilot) -> void:
	var here: Callable = func(marker: String) -> Transform3D: return (get_node("Markers/" + marker) as Marker3D).global_transform
	var north: Vector3 = Vector3(0.0, 0.0, -1.0)
	var screen: CraftingScreen = $CraftingScreen
	pilot.wait(1.0)
	for name: String in ["Branch1", "LooseStone4", "Branch2", "LooseStone1", "Branch3", "LooseStone2", "Branch4", "LooseStone3", "Branch5", "LooseStone5"]:
		pilot.walk_to(get_node("Beachcombing/" + name), 5.0, 1.0, true).wait(0.2).tap(&"action").wait(0.25)
	pilot.warp(player, here.call("ByBench")).wait(0.3).walk_to(station, 4.0, 2.0).wait(0.4).tap(&"action").wait(1.2) # the bench opens
	pilot.call_step(func() -> void: screen.craft_index(0)).wait(1.4).call_step(screen.hide_menu).wait(0.6) # the axe, and the screen closed
	pilot.warp(player, here.call("ByBush")).wait(0.3).walk_to($Woods/Bush1, 4.0, 1.4).wait(0.2)
	for i: int in 2:
		pilot.tap(&"attack").wait(0.9)
	pilot.call_step(func() -> void: player.inventory.use_item(BERRIES, 2)).wait(0.8) # eaten on the spot
	pilot.warp(player, here.call("ByStream")).wait(0.3).walk_to(stream, 4.0, 1.2).wait(0.3).tap(&"action").wait(0.8) # a drink
	pilot.warp(player, here.call("ByTrees")).wait(0.3)
	for tree_name: String in ["Tree1", "Tree4", "Tree2"]:
		var tree: Gatherable = get_node("Woods/" + tree_name)
		pilot.walk_to(tree, 5.0, 1.6).wait(0.2)
		for i: int in 9:
			pilot.tap(&"attack").wait(0.85)
		pilot.wait(0.3)
	pilot.warp(player, here.call("ByBench")).wait(0.3).walk_to(station, 4.0, 2.0).wait(0.3).tap(&"action").wait(1.0)
	pilot.call_step(func() -> void: screen.craft_index(1)).wait(1.2).call_step(screen.hide_menu).wait(0.5) # the pickaxe
	pilot.warp(player, here.call("ByBoulder")).wait(0.3).walk_to($Woods/Boulder1, 5.0, 1.9).wait(0.2)
	for i: int in 9:
		pilot.tap(&"attack").wait(0.85)
	pilot.warp(player, here.call("ByBench")).wait(0.3).walk_to(station, 4.0, 2.0).wait(0.3).tap(&"action").wait(1.0)
	pilot.call_step(func() -> void: screen.craft_index(2)).wait(1.4).call_step(screen.hide_menu).wait(0.5) # the shelter
	pilot.walk_to(shelter, 5.0, 2.5).wait(2.5)
