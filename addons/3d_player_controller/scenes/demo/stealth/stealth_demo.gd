extends DemoScene
## The stealth style: guards on patrol with vision cones drawn on the ground, a crouch that keeps you under
## their eyes, a takedown from behind that lands ten times harder, the Stealth ability to cross the open yard,
## the alarm when a cone fills, hiding until they lose you, the sealed orders from the pavilion and the far gate.

const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/stealth_orders.tres")
const INTEL: Item = preload("res://addons/3d_player_controller/resources/items/intel.tres")

@export var guards: Node3D
@export var exit: Area3D
@export var navigation_region: NavigationRegion3D

var alarms: int = 0 ## How many times a guard raised the alarm.
var escaped: bool = false


func _ready() -> void:
	super()
	bake_navigation(navigation_region) # after the setup, so the enemies path around the walls a frame or two in


func setup_player(target: Player) -> void:
	target.enable_stamina = false
	for pickup: Node in find_children("*", "ItemPickup", true, false):
		(pickup as ItemPickup).picked_up.connect(_on_picked_up)
	for cone: Node in find_children("*", "VisionCone", true, false):
		(cone as VisionCone).spotted.connect(_on_spotted)
	if target.quest_log:
		target.quest_log.start(QUEST)


func _on_picked_up(by: Player, _count: int) -> void:
	if by and by.inventory and by.inventory.count_of(INTEL) > 0 and by.quest_log and not by.quest_log.is_objective_done(QUEST, &"take_orders"):
		by.quest_log.progress(&"take_orders")


func _on_spotted(_who: Player) -> void:
	alarms += 1


func _on_exit_body_entered(body: Node3D) -> void:
	if body is Player and not escaped:
		escaped = true
		if player and player.quest_log:
			player.quest_log.progress(&"reach_exit")


func guard(index: int) -> EnemyNpc:
	return guards.get_node("Guard%d" % index) as EnemyNpc


func hunted() -> bool:
	for node: Node in guards.get_children():
		if node is EnemyNpc and (node as EnemyNpc).target == player:
			return true
	return false


## The recording: the sword, a crouch behind the crates until the first guard has passed, a takedown on his back,
## the gap in the wall, Stealth across the yard under the second guard's nose, the orders, a cone filled on
## purpose and the alarm, the run to the rocks, the guards losing the trail, and the gate.
func build_autopilot(pilot: DemoAutopilot) -> void:
	var here: Callable = func(marker: String) -> Transform3D: return (get_node("Markers/" + marker) as Marker3D).global_transform
	var north: Vector3 = Vector3(0.0, 0.0, -1.0)
	var g1: EnemyNpc = guard(1)
	var g3: EnemyNpc = guard(3)
	var behind_g1: Callable = func() -> Vector3: return g1.global_position + g1.global_basis.z * 1.1 # its back is +Z
	pilot.wait(1.0).walk_to($Dressing/Sword, 4.0, 0.6).wait(0.5)
	pilot.warp(player, here.call("BehindCrates")).wait(0.3).press(&"crouch").wait(0.6)
	pilot.wait_until(func() -> bool: return g3.global_position.x > 6.0, 16.0) # the patrol crosses the far yard; time to move
	pilot.walk_to(behind_g1, 6.0, 0.8).release(&"crouch").wait(0.2).tap(&"attack").wait(1.2) # up behind the sentry: the takedown
	pilot.wait_until(func() -> bool: return g1.is_dead, 3.0).wait(0.6)
	pilot.warp(player, here.call("Gap")).wait(0.4).press(&"crouch").walk(north, 1.6).release(&"crouch").wait(0.3)
	pilot.tap(&"ability").wait(0.6).walk_to($Dressing/Intel, 8.0, 1.0).wait(0.4).tap(&"action").wait(0.6) # Stealth: unseen across the yard, the orders
	pilot.warp(player, here.call("Open")).wait(0.6).tap(&"ability").wait(0.3) # the veil dropped in the open
	pilot.watch_until(g3, func() -> bool: return hunted(), 12.0).watch(g3, 1.4) # in plain view of the third guard: the alarm
	pilot.walk_to(here.call("HideRock").origin, 6.0, 0.8, true).press(&"crouch").wait_until(func() -> bool: return not hunted(), 14.0).wait(0.8).release(&"crouch") # gone behind the rocks, and they give up
	pilot.warp(player, here.call("GateRun")).wait(0.3).walk_to($Exit/ExitTrigger, 6.0, 1.0, true).wait(2.0)
