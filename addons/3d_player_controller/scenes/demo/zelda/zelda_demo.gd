extends DemoScene
## The Zelda style: Breath of the Wild controls, a village with an elder and an errand, equipment on stands and
## in a chest, coins in the grass, a raiders' camp to clear with lock-on and the sword, a pond to swim, a cliff
## to climb and a glide off the top. The HUD is on and its buttons take their contextual words as you go.

const GOLD_COIN: Item = preload("res://addons/3d_player_controller/resources/items/gold_coin.tres")
const RED_POTION: Item = preload("res://addons/3d_player_controller/resources/items/red_potion.tres")
const ARROW: Item = preload("res://addons/3d_player_controller/resources/items/arrow.tres")

@onready var pond: Area3D = $Pond/Water
@onready var chest: TreasureChest = $Shrine/TreasureChest
@onready var elder: TalkingNpc = $Village/Elder
@onready var raiders: Node3D = $Camp/Raiders


func setup_player(target: Player) -> void:
	target.enable_stamina = true
	target.enable_paraglider = true
	target.inventory.item_used.connect(_on_item_used)
	for raider: Node in raiders.get_children():
		if raider is EnemyNpc:
			(raider as EnemyNpc).died.connect(_on_raider_died)
	chest.opened.connect(_on_chest_opened)


## A potion drunk from the inventory heals forty; the inventory only says it was used, the game does the rest.
func _on_item_used(item: Item, count: int) -> void:
	if item == RED_POTION and player:
		player.heal(40.0 * count)


func _on_raider_died() -> void:
	if player and player.quest_log:
		player.quest_log.progress(&"defeat_raider")


func _on_chest_opened(_by: Player) -> void:
	if player and player.quest_log:
		player.quest_log.progress(&"open_chest")


func _on_pond_body_entered(body: Node3D) -> void:
	if body is Player:
		(body as Player).enter_water(pond)


func _on_pond_body_exited(body: Node3D) -> void:
	if body is Player:
		(body as Player).exit_water(pond)


## The recording: gear up in the village, take the errand, coins, the camp, the chest, the pond, the cliff, the glide.
func build_autopilot(pilot: DemoAutopilot) -> void:
	var here: Callable = func(marker: String) -> Transform3D: return (get_node("Markers/" + marker) as Marker3D).global_transform
	var north: Vector3 = Vector3(0.0, 0.0, -1.0)
	if OS.get_cmdline_user_args().has("--leg=cliff"): # just the end, for a quick look at the climb and the glide
		pilot.warp(player, here.call("ByCliff")).wait(0.4).walk(Vector3.LEFT, 0.5).tap(&"jump").walk(Vector3.LEFT, 0.4).tap(&"jump")
		pilot.walk(Vector3.LEFT, 7.0, true).walk(Vector3.LEFT, 4.5).wait(0.6).tap(&"jump").wait(1.0).tap(&"jump").wait(1.5)
		_glide_leg(pilot, here.call("OnCliff"), north)
		return
	pilot.wait(1.5)
	pilot.walk(north, 1.8).wait(0.6) # over the sword on its stand
	pilot.tap(&"attack").wait(0.8).tap(&"attack").wait(1.2)
	pilot.warp(player, here.call("ByElder")).wait(0.6).tap(&"action").wait(1.8) # talk: the greeting types out
	pilot.tap(&"action").wait(0.7).tap(&"action").wait(3.4) # the rest at once, then the errand accepted; the task types
	pilot.tap(&"action").wait(0.8).tap(&"action").wait(0.6) # the rest at once, then done
	pilot.warp(player, here.call("ByCoins")).wait(0.3)
	for i: int in 3:
		pilot.walk(north, 0.75).tap(&"action").wait(0.5)
	pilot.warp(player, here.call("ByCamp")).wait(0.4).walk(north, 1.4).wait(0.3)
	for i: int in 14:
		pilot.hold(&"focus", 0.1).tap(&"attack").wait(0.5)
	pilot.wait(1.0)
	pilot.warp(player, here.call("ByChest")).wait(0.4).walk(north, 1.3).wait(0.3).tap(&"action").wait(2.2)
	pilot.warp(player, here.call("ByPond")).wait(0.3).walk(-north, 2.5).hold(&"sprint", 2.0).wait(0.5)
	# The cliff: weapons away (a climber's hands are busy), jump at the wall and jump again in the air to grab it,
	# then climb; a cut to the top, and off it
	pilot.call_step(func() -> void: player.inventory.unequip_all()).wait(1.2)
	pilot.warp(player, here.call("ByCliff")).wait(0.6).walk(Vector3.LEFT, 0.5).tap(&"jump").walk(Vector3.LEFT, 0.4).tap(&"jump")
	pilot.walk(Vector3.LEFT, 7.0, true).walk(Vector3.LEFT, 4.5).wait(0.6).tap(&"jump").wait(1.0).tap(&"jump").wait(1.5)
	_glide_leg(pilot, here.call("OnCliff"), north)


## Cut to the cliff top, get the breath back (exhausted, the glider stays shut), run off the edge and open it in the air.
func _glide_leg(pilot: DemoAutopilot, top: Transform3D, north: Vector3) -> void:
	var rested: Callable = func() -> bool: return not player.is_exhausted and player.stamina.stamina >= player.stamina.max_value
	var falling: Callable = func() -> bool: return player.current_state == NodeStateMachine.States.FALLING
	pilot.warp(player, top).wait(1.0).wait_until(rested, 12.0).wait(0.5)
	pilot.walk(north, 0.9).wait_until(falling, 2.0).wait(0.25).tap(&"jump").walk(north, 5.0).wait(1.5)
