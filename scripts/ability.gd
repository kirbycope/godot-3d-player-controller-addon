class_name Ability
extends Resource
## A World of Warcraft style ability picked from the ability wheel and cast with the "ability" action.
##
## Subclass and override [method activate] (and [method deactivate] for toggles). Timing, costs,
## cooldowns and the VFX/SFX of each [enum Phase] are handled by [Abilities]; the resource only
## applies the effect and says what to play.

enum Phase { CHANNELING, CASTING, IMPACT } ## Channeling runs for the cast time, casting fires on the caster when the effect lands, impact lands at [method get_impact_position].
enum Target { SELF, FOCUS } ## SELF lands on the caster; FOCUS lands on the locked-on target, or where the Player aims without one.

@export var display_name: String = ""
@export var icon: Texture2D
@export var cooldown: float = 0.0 ## Seconds before the ability can be cast again.
@export var cast_time: float = 0.0 ## Seconds the Player must stand still before the effect lands; 0 is instant.
@export var stamina_cost: float = 0.0 ## Stamina spent when the effect lands; the cast is refused with less.
@export var channel_while_moving: bool = false ## Keeps a timed cast going while the Player moves; off, any movement interrupts it as in WoW. Attacks always interrupt.
@export var is_toggle: bool = false ## Stays active until cast again or [method deactivate] is called.
@export var ends_on_attack: bool = false ## Active toggles end when the Player attacks or fires a weapon.
@export var fx_lifetime: float = 3.0 ## Seconds a one-shot casting or impact VFX instance stays before it is freed.
@export var target_mode: Target = Target.SELF
@export_group("Projectile", "projectile_")
@export var projectile_speed: float = 0.0 ## Metres per second; above 0 the casting VFX/SFX fly to the target as a [SpellProjectile] and impact lands on arrival.
@export var projectile_homing: bool = true ## The bolt follows a moving target and always arrives, WoW style.
@export_group("Channeling", "channeling_")
@export var channeling_vfx: PackedScene ## Kept on the caster for the cast time.
@export var channeling_sfx: AudioStream ## Played for the cast time; loop the stream for long casts.
@export_group("Casting", "casting_")
@export var casting_vfx: PackedScene ## One-shot on the caster when the effect fires.
@export var casting_sfx: AudioStream
@export_group("Impact", "impact_")
@export var impact_vfx: PackedScene ## One-shot at [method get_impact_position] when the effect fires.
@export var impact_sfx: AudioStream


## Applies the effect; return false to refuse the cast so no cost or cooldown is spent.
func activate(_player: Player) -> bool:
	return true


## Ends an active toggle's effect.
func deactivate(_player: Player) -> void:
	pass


func get_vfx(phase: Phase) -> PackedScene:
	return [channeling_vfx, casting_vfx, impact_vfx][phase]


func get_sfx(phase: Phase) -> AudioStream:
	return [channeling_sfx, casting_sfx, impact_sfx][phase]


## Applies the effect to [param target] when the impact lands (on arrival for projectiles); null when nothing was aimed at.
func impact(_player: Player, _target: Node3D) -> void:
	pass


## The node the impact lands on; null when nothing is locked on in FOCUS mode.
func get_target(player: Player) -> Node3D:
	return player if target_mode == Target.SELF else player.current_focus_target


## Where the impact lands: the caster, the target, or the aim point when nothing is locked on.
func get_impact_position(player: Player) -> Vector3:
	var target: Node3D = get_target(player)
	if target == player:
		return player.global_position
	if is_instance_valid(target):
		return Focus.get_focus_target_position(target)
	var ray: RayCast3D = player.projectile_raycast
	ray.force_raycast_update()
	return ray.get_collision_point() if ray.is_colliding() else ray.global_position - ray.global_basis.z * Firearm.RAY_MISS_DISTANCE
