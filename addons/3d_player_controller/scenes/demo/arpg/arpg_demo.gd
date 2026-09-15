extends DemoScene
## The action RPG style: a fixed view from above ([member Camera.locked_view]), click to move with the mouse or the
## stick on a pad, a sword and shield at the door, a Fireball on the shoulder button, halls of ghouls in waves
## that drop gold and potions where they fall, and the Crypt Lord on his sigil at the end.

const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/arpg_crypt.tres")
const GOLD_COIN: Item = preload("res://addons/3d_player_controller/resources/items/gold_coin.tres")
const RED_POTION: Item = preload("res://addons/3d_player_controller/resources/items/red_potion.tres")
const FIREBALL: Ability = preload("res://addons/3d_player_controller/resources/abilities/fireball.tres")
const PICKUP_SCENE: PackedScene = preload("res://addons/3d_player_controller/inventory/scenes/item_pickup.tscn")
const POTION_HEAL: float = 40.0

@export var spawner: WaveSpawner
@export var lord: EnemyNpc
@export var hall_trigger: Area3D
@export var lair_trigger: Area3D
@export var navigation_region: NavigationRegion3D
@export var coins_per_ghoul: int = 5
@export var potion_chance: float = 0.34

var gold_looted: int = 0
var _lord_woken: bool = false


func _ready() -> void:
	super()
	bake_navigation(navigation_region)


func setup_player(target: Player) -> void:
	target.enable_stamina = false
	target.health.max_energy = 100.0
	target.health.energy = 100.0
	target.health.energy_regen = 8.0
	if target.camera is Camera:
		(target.camera as Camera).locked_view = true
		(target.camera as Camera).locked_pitch_degrees = -50.0
		(target.camera as Camera).locked_distance = 7.0
	if target.abilities:
		target.abilities.abilities = [FIREBALL]
		target.abilities.active_ability = FIREBALL
	target.inventory.item_used.connect(_on_item_used)
	spawner.player = target
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	spawner.wave_cleared.connect(_on_wave_cleared)
	lord.died.connect(_on_lord_died)
	if target.quest_log:
		target.quest_log.start(QUEST)


func _on_item_used(item: Item, count: int) -> void:
	if item == RED_POTION and player:
		player.heal(POTION_HEAL * count)


## Every ghoul drops gold where it falls, and a potion now and then.
func _on_enemy_spawned(enemy: EnemyNpc) -> void:
	enemy.died.connect(_drop_loot.bind(enemy))


func _drop_loot(enemy: EnemyNpc) -> void:
	if not is_instance_valid(enemy):
		return
	var at: Vector3 = enemy.global_position
	_drop(GOLD_COIN, coins_per_ghoul, at + Vector3(0.4, 0.1, 0.0))
	if randf() < potion_chance:
		_drop(RED_POTION, 1, at + Vector3(-0.5, 0.1, 0.3))


func _drop(item: Item, count: int, at: Vector3) -> void:
	var pickup: ItemPickup = PICKUP_SCENE.instantiate() as ItemPickup
	pickup.item = item
	pickup.count = count
	pickup.auto_take = true
	pickup.show_icon = item == RED_POTION
	add_child(pickup)
	pickup.global_position = at
	pickup.picked_up.connect(func(_by: Player, taken: int) -> void:
		if item == GOLD_COIN:
			gold_looted += taken)


func _on_wave_cleared(_index: int) -> void:
	if player and player.quest_log:
		player.quest_log.progress(&"clear_wave")


func _on_lord_died() -> void:
	if player and player.quest_log:
		player.quest_log.progress(&"slay_lord")


## Into the halls: the first wave.
func _on_hall_body_entered(body: Node3D) -> void:
	if body is Player and not spawner.running and spawner.wave < 0:
		spawner.start()


## Onto the sigil: the Crypt Lord wakes.
func _on_lair_body_entered(body: Node3D) -> void:
	if body is Player and not _lord_woken and not lord.is_dead:
		_lord_woken = true
		lord.aggro(body)


func nearest_enemy(fallback: Vector3) -> Variant:
	var best: EnemyNpc = null
	var best_distance: float = INF
	var candidates: Array[EnemyNpc] = spawner.alive.duplicate()
	if not lord.is_dead:
		candidates.append(lord)
	for enemy: EnemyNpc in candidates:
		if is_instance_valid(enemy) and not enemy.is_dead:
			var distance: float = enemy.global_position.distance_to(player.global_position)
			if distance < best_distance:
				best_distance = distance
				best = enemy
	return best if best else fallback


## The recording: a click to walk to the sword and one to the shield, the halls (sword swings and fireballs
## between rolls of the stick), the loot underfoot, a potion when it gets close, and the Crypt Lord.
func build_autopilot(pilot: DemoAutopilot) -> void:
	var here: Callable = func(marker: String) -> Transform3D: return (get_node("Markers/" + marker) as Marker3D).global_transform
	var wave_over: Callable = func() -> bool: return spawner.alive.is_empty()
	var wave_on: Callable = func() -> bool: return not spawner.alive.is_empty()
	var lord_down: Callable = func() -> bool: return lord.is_dead
	var potion_when_low: Callable = func() -> void:
		if player.health.health < 45.0 and player.inventory.count_of(RED_POTION) > 0:
			player.inventory.use_item(RED_POTION, 1)
	pilot.wait(1.0).click($Dressing/BronzeSword).wait_until(func() -> bool: return player.equipped_sword_1h, 6.0).wait(0.3)
	pilot.click($Dressing/WoodenShield).wait_until(func() -> bool: return player.inventory.has_equipment(Equipment.EquipmentType.SWORD_AND_SHIELD), 6.0).wait(0.4)
	pilot.click(func() -> Vector3: return player.global_position + Vector3(0.0, 0.0, -6.0)).wait(2.0) # a click on the floor ahead
	pilot.walk_to(here.call("HallMouth").origin, 8.0, 1.0).wait_until(wave_on, 8.0).wait(0.5)
	for wave: int in 3:
		pilot.tap(&"ability").wait(1.2) # a fireball into the pack
		pilot.melee(40.0, wave_over, 3, -1.0, potion_when_low).wait(0.4)
		pilot.tap(&"ability").wait(0.4)
		if wave < 2:
			pilot.wait_until(wave_on, 8.0).wait(0.3)
	pilot.walk_to(here.call("MidHall").origin, 10.0, 1.0).wait(1.5) # the gold underfoot
	pilot.walk_to(here.call("LairMouth").origin, 12.0, 1.0).wait_until(func() -> bool: return _lord_woken, 10.0).wait(0.6)
	pilot.tap(&"ability").wait(1.2)
	pilot.melee(90.0, lord_down, 3, -1.0, potion_when_low).wait(2.5)
