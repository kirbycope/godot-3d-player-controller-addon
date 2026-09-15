extends DemoScene
## The Souls style: lock-on, a stamina bar every swing and roll draws on, a tap of Sprint to roll through a blow,
## a bonfire to rest at that heals, refills the flasks and puts the dead back on their feet, souls that drop where
## you fall and wait to be picked up again, a corridor of hollows, a greatsword on an altar, a fog gate and a boss.

const SOULS: Item = preload("res://addons/3d_player_controller/resources/items/souls.tres")
const RED_POTION: Item = preload("res://addons/3d_player_controller/resources/items/red_potion.tres")
const PICKUP_SCENE: PackedScene = preload("res://addons/3d_player_controller/inventory/scenes/item_pickup.tscn")

const FLASK_HEAL: float = 40.0

@export var bonfire: Bonfire
@export var hollows: Node3D
@export var boss: EnemyNpc
@export var fog_gate: Area3D
@export var hollow_souls: int = 50 ## What a hollow leaves behind.
@export var boss_souls: int = 500

var bloodstain: ItemPickup = null ## Where the last death dropped the souls; a second death moves it.
var deaths: int = 0
var _boss_engaged: bool = false


func setup_player(target: Player) -> void:
	target.enable_stamina = true
	target.enable_dodge = true
	target.attack_stamina_cost = 15.0
	target.dodge_stamina_cost = 20.0
	target.inventory.item_used.connect(_on_item_used)
	target.health.died.connect(_on_player_died)
	target.respawned.connect(_on_player_respawned)
	for hollow: Node in hollows.get_children():
		if hollow is EnemyNpc:
			(hollow as EnemyNpc).died.connect(_on_enemy_died.bind(hollow_souls))
	boss.died.connect(_on_enemy_died.bind(boss_souls))


## A flask drunk heals; the inventory only says it was used.
func _on_item_used(item: Item, count: int) -> void:
	if item == RED_POTION and player:
		player.heal(FLASK_HEAL * count)


func _on_enemy_died(souls: int) -> void:
	if player and player.inventory:
		player.inventory.add_item(SOULS, souls)


## Death leaves the souls where you fell, as a pickup; the next death moves them, so only one pile is ever out.
func _on_player_died() -> void:
	deaths += 1
	var carried: int = player.inventory.count_of(SOULS)
	if carried <= 0:
		return
	player.inventory.remove_item(SOULS, carried)
	if is_instance_valid(bloodstain):
		bloodstain.queue_free()
	bloodstain = PICKUP_SCENE.instantiate() as ItemPickup
	bloodstain.name = "Bloodstain"
	bloodstain.item = SOULS
	bloodstain.count = carried
	add_child(bloodstain)
	bloodstain.global_position = player.global_position + Vector3(0.0, 0.1, 0.0)


## Coming back to the fire is a rest: flasks full, the hollows back at their posts. The boss stays engaged only
## while the fight is on; a death ends it.
func _on_player_respawned() -> void:
	bonfire.refill_flasks(player)
	bonfire.revive_enemies()
	_boss_engaged = false


## Through the fog: the boss wakes and its bar comes up.
func _on_fog_gate_body_entered(body: Node3D) -> void:
	if body is Player and not boss.is_dead and not _boss_engaged:
		_boss_engaged = true
		boss.aggro(body)


func hollows_standing() -> bool:
	for hollow: Node in hollows.get_children():
		if hollow is EnemyNpc and not (hollow as EnemyNpc).is_dead:
			return true
	return false


## The recording: rest, gear up, the corridor with rolls between swings, a flask, the fog gate and a death to the
## boss with the short sword, the greatsword off the altar, the run back for the souls, and the boss brought down.
func build_autopilot(pilot: DemoAutopilot) -> void:
	var here: Callable = func(marker: String) -> Transform3D: return (get_node("Markers/" + marker) as Marker3D).global_transform
	var north: Vector3 = Vector3(0.0, 0.0, -1.0)
	var player_down: Callable = func() -> bool: return not player.health.is_alive()
	var boss_down: Callable = func() -> bool: return boss.is_dead
	var flask_when_low: Callable = func() -> void:
		if player.health.health < 45.0 and player.inventory.count_of(RED_POTION) > 0:
			player.inventory.use_item(RED_POTION, 1)
	pilot.wait(1.0).walk_to(bonfire, 4.0, 1.6).wait(0.5).tap(&"action").wait(1.4) # rest: the prompt reads Rest
	pilot.walk_to($Gear/BronzeSword, 4.0, 0.6).wait(0.5).walk_to($Gear/WoodenShield, 4.0, 0.6).wait(0.6)
	pilot.warp(player, here.call("Corridor")).wait(0.4)
	for hollow: Node in hollows.get_children(): # one at a time, each waking as the Player comes near
		var dead: Callable = func() -> bool: return (hollow as EnemyNpc).is_dead
		pilot.walk_to(hollow, 6.0, 2.6).wait(0.3).melee(30.0, dead, 2, -1.0, flask_when_low).wait(0.6)
	pilot.call_step(func() -> void: player.inventory.use_item(RED_POTION, 1)).wait(1.0) # a flask
	pilot.warp(player, here.call("Gate")).wait(0.5).walk(north, 2.6).wait(0.4) # through the fog, into the ring, with the short sword
	pilot.melee(40.0, player_down, 4, 0.0) # greedy combos, backsteps only: the boss takes its due
	pilot.wait_until(func() -> bool: return player.health.is_alive() and player.global_position.distance_to(bonfire.global_position) < 6.0, 8.0).wait(1.5)
	pilot.warp(player, here.call("Altar")).wait(0.4).walk_to($Gear/BronzeGreatsword, 4.0, 1.2).wait(0.8) # the greatsword this time
	pilot.warp(player, here.call("Gate")).wait(0.4).walk(north, 1.6).wait(0.3)
	pilot.walk_to(func() -> Variant: return bloodstain if is_instance_valid(bloodstain) else player.global_position, 8.0, 1.0).wait(0.3).tap(&"action").wait(0.6) # the souls back
	pilot.melee(90.0, func() -> bool: return boss.is_dead or not player.health.is_alive(), 2, -1.0, flask_when_low).wait(2.5)
