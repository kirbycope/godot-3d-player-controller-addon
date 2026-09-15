extends DemoScene
## The survival horror style: a black cellar, a flashlight on a battery that runs down, batteries and torn
## pages on the crates, a thing with an axe that only moves while the light is off it, the cellar key on the far
## shelves and a locked door at the top of the stairs. The flashlight is on the d-pad's bottom button for the run.

const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/horror_cellar.tres")
const BATTERY: Item = preload("res://addons/3d_player_controller/resources/items/battery.tres")
const CELLAR_KEY: Item = preload("res://addons/3d_player_controller/resources/items/cellar_key.tres")
const BATTERY_SECONDS: float = 30.0

@export var flashlight: Flashlight
@export var stalker: EnemyNpc
@export var door: LockedDoor
@export var exit: Area3D
@export var battery_bar: ProgressBar
@export var navigation_region: NavigationRegion3D

var escaped: bool = false


func _ready() -> void:
	super()
	bake_navigation(navigation_region) # after the setup, so the enemies path around the walls a frame or two in


func setup_player(target: Player) -> void:
	target.enable_stamina = false
	target.controls.bind_slot("button_12", &"flashlight", "Flashlight")
	flashlight.player = target
	flashlight.battery_changed.connect(_on_battery_changed)
	_on_battery_changed(flashlight.battery, flashlight.capacity)
	target.inventory.item_used.connect(_on_item_used)
	for pickup: Node in find_children("*", "ItemPickup", true, false):
		(pickup as ItemPickup).picked_up.connect(_on_picked_up)
	door.opened.connect(_on_door_opened)
	if target.quest_log:
		target.quest_log.start(QUEST)


## A battery goes straight into the torch; the key is the run.
func _on_picked_up(by: Player, _count: int) -> void:
	if by == null or by.inventory == null:
		return
	var batteries: int = by.inventory.count_of(BATTERY)
	if batteries > 0:
		by.inventory.use_item(BATTERY, batteries)
		# The first battery taken is when it notices you
		if stalker.target == null and not stalker.is_dead:
			stalker.aggro(by)
	if by.inventory.count_of(CELLAR_KEY) > 0 and by.quest_log and not by.quest_log.is_objective_done(QUEST, &"find_key"):
		by.quest_log.progress(&"find_key")


func _on_item_used(item: Item, count: int) -> void:
	if item == BATTERY:
		flashlight.battery += BATTERY_SECONDS * count


func _on_battery_changed(seconds_left: float, capacity: float) -> void:
	if battery_bar:
		battery_bar.value = seconds_left / maxf(capacity, 0.01)


func _on_door_opened(_by: Player) -> void:
	pass


func _on_exit_body_entered(body: Node3D) -> void:
	if body is Player and not escaped:
		escaped = true
		if player and player.quest_log:
			player.quest_log.progress(&"get_out")


## The recording: the torch on, the first page, a battery, the thing seen and frozen in the beam, the light off
## and it closing in, on again, the second page and the key, the stairs, the door.
func build_autopilot(pilot: DemoAutopilot) -> void:
	var here: Callable = func(marker: String) -> Transform3D: return (get_node("Markers/" + marker) as Marker3D).global_transform
	pilot.wait(1.5).tap(&"flashlight").wait(1.0)
	pilot.warp(player, here.call("ByNote1")).wait(0.4).walk_to($Dressing/Note1, 4.0, 1.2).wait(0.3)
	talk(pilot, 1)
	pilot.warp(player, here.call("ByBattery1")).wait(0.3).walk_to($Dressing/Battery1, 4.0, 1.1).wait(0.3).tap(&"action").wait(0.6)
	pilot.warp(player, here.call("Corner")).wait(0.3)
	pilot.watch(stalker, 3.0).wait(0.2) # it stands in the beam, seven metres off
	pilot.tap(&"flashlight").watch(stalker, 3.0) # dark: it comes
	pilot.tap(&"flashlight").watch(stalker, 2.5) # light: it stops
	pilot.warp(player, here.call("ByNote2")).wait(0.3).walk_to($Dressing/Note2, 4.0, 1.2).wait(0.3)
	talk(pilot, 1)
	pilot.warp(player, here.call("Corner")).wait(0.2).walk_to($Dressing/CellarKey, 8.0, 1.1).wait(0.3).tap(&"action").wait(0.6)
	pilot.warp(player, here.call("Hall")).wait(0.3).watch(stalker, 2.0)
	pilot.warp(player, here.call("StairFoot")).wait(0.3).walk_to(door, 8.0, 1.6, true).wait(0.4).tap(&"action").wait(1.4)
	pilot.walk_to($Stairs/ExitTrigger, 6.0, 1.0).wait(2.0)
