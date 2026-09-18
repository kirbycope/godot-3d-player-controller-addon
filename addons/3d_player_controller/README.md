# 3D Player Controller for Godot 4.8+

A feature-complete, modular 3D character controller built for **Godot 4.8+** using [CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html), [AnimationTree](https://docs.godotengine.org/en/stable/classes/class_animationtree.html), and Root Motion. Includes a full locomotion finite state machine, first- and third-person camera system, equipment and combat system, stamina mechanics, radial inventory, contextual multi-platform input hints, Zelda, GTA and platformer control schemes, checkpoints and a death flow, a save game, NPCs (enemies, followers and talkers), dialogue and quests, and local split screen: the pieces a new project drops in to start making a game.

> [!NOTE]
> **Plugin Activation vs Scene Usage**:
> All core scripts use `class_name` (`Player`, `NodeStateMachine`, `Inventory`, `RadialMenu`, `Equipment`, `Camera`, `HeldObject`, etc.).
> - **Direct Usage**: You can instantiate `res://addons/3d_player_controller/scenes/player.tscn` directly into your scenes without enabling anything in Project Settings.
> - **Enabling the Plugin**: Enabling **3D Player Controller** in **Project Settings > Plugins** registers the addon and custom editor utilities.

---

## Features

### 1. Locomotion Finite State Machine (`NodeStateMachine`)
Organized state machine architecture separating primary lower-body locomotion states from upper-body actions:
- **Standing / Walking / Running**: Smooth acceleration, deceleration, and camera-relative motion.
- **Sprinting**: High-speed locomotion linked to stamina consumption.
- **Jumping & Falling**: Air control, coyote time, and smooth landing blending.
- **Crouching & Sliding**: Crouch walking and momentum-based sprinting slides.
- **Dodging**: with `enable_dodge` on, a tap of Sprint rolls (a backstep when still) with invulnerability frames and a stamina cost; see section 14.
- **Climbing**: Raycast-assisted wall detection, ledge hopping, and wall climbing. Walls become slippery during rain (BotW style): the climber periodically slides down, sprint climbing is blocked, and the climb animation slows (tunable via the `Rain Slipping` export group).
- **Hanging & Shimmy**: Braced and free-hang wall gripping with directional shimmy.
- **Swimming & Fast Swimming**: Water volume detection (`WATER` group), buoyancy, and surface swimming. Hard water entries spawn a one-shot droplet/foam splash (`water_splash.tscn`, tunable impact threshold). Swimmers ripple the water through WeatherFX's `WaterRipples` node on the water area (it renders every body in the water into the ripple simulation), so the controller knows nothing about the water shader.
- **Diving**: Hold crouch while swimming to dive below the surface; hold jump to ascend and surface. The player model pitches around a hip pivot to follow the swim direction (camera stays level), gentle buoyancy floats you back to the surface when shallow, and stamina drains constantly underwater as a breath meter — exhaustion respawns you at the last safe shore. A fullscreen underwater filter (tint + wavy refraction + vignette) activates whenever the camera submerges. Contextual HUD controls swap between `Dive`/`Climb Out` and `Dive Deeper`/`Surface` automatically.
- **Paragliding**: Deployable glider with steering control and mid-air cancel. Thermal updrafts grant an immediate `+6 m/s` catch boost on entry (BotW standard) plus continued lift and stamina recovery; all glide/dive/updraft physics are exported tunables on the `Paragliding` state node.
- **Riding** (`Riding`): one state for anything the Player gets on. A rideable (a skateboard, a vehicle, a horse) calls `player.mount(self)`; the state hands it the Player, forwards input events and the physics tick, plays the animations it asks for, and `player.dismount()` gets off. The state does the Player's side of getting on and off (the get-on and get-off clips, the camera, the crosshair, the collision shape and the step-up ray), so a rideable never sets Player flags. Skateboarding lives in the `tcps` addon and driving in the `gta` addon, each with its own camera that the state makes current while ridden.
- **Flying**: 3D spatial flying with vertical ascending/descending.
- **Sitting & Ragdoll**: Physical bone ragdoll simulation with get-up recovery.

**State node API** — `state.gd` (`NodeStateMachine`) is both the machine node and the base class of every state node under it:
- `start()` / `stop()` on the base enable/disable the state node and set/clear `player.current_state` (`States.NONE = -1` when no state is active). States extend them with `super.start()` / `super.stop()`; a node's `state` is derived from its name (`Standing` -> `States.STANDING`). `travel(from, to)` calls them directly.
- `action(keyboard, pad)` resolves a state's exported action pair for the current input type (`Controls.InputType.KEYBOARD_MOUSE` vs controller/touch).
- The base connects `Player.locomotion_node_changed` once; states override `_on_locomotion_node_changed(state_path)` (early-returning unless `process_mode == PROCESS_MODE_INHERIT`) to react to animation hand-offs (slide end, climb-on, hops, attacks) instead of polling the AnimationTree. Read `player.current_locomotion_node` / `player.current_locomotion_path` rather than the playback objects. `whistled(player)` is emitted on the authority when the `whistle` action is pressed on foot (a rideable's `ride_input` gets it first while riding); the game decides who answers, for instance the world's horse.
- `get_contextual_controls(input_type)` returns only state-specific labels; the base adds the shared `Perspective` / `Screenshot` / `Pause Menu` labels.
- Standing re-derives its grounded locomotion from `Inventory.equipment_changed` and `Player.exhausted_changed`; only the exhausted idle/moving swap (held analog input) is polled.
- Timers are `Timer` children (physics-time): `Pushing.stop_grace_timer`, `Climbing.rain_slip_timer`, `Attacking.boxing_inactivity_timer`, `Attacking.attack_timeout_timer`; Flying's double-tap uses a `SceneTreeTimer`.
- An exhausted Player cannot start an attack from Standing or Crouching: the HeavyBreathing idle has no transition into the attack animations, so the swing would never play. As a backstop, Attacking returns to Standing after `attack_timeout` (1 s) if no attack animation has started, so `is_attacking` can never stay set on a swing that did not happen.
- `Player.lethal_fall_speed` (15 m/s) is the shared ragdoll landing threshold for jumping and falling; `Player.wall_leap_horizontal_speed` / `wall_leap_vertical_speed` tune the climbing/hanging back-eject (`Player.leap_off_wall()`), and `Player.face_wall(delta)` / `clear_ledge_visuals()` are shared by the wall states.

- **Swimming ledges**: while swimming, `Swimming` moves the `LedgeDetectionHorizontal` ray to `LEDGE_RAY_DEPTH` (0.3 m) below the water surface and restores its scene height on exit, so rims flush with the water still register and jump at `SwimmingAtEdge` mantles out.

### 2. First & Third Person Camera (`Camera`)
- Dynamic toggle between **First-Person** and **Third-Person** perspectives.
- SpringArm collision avoidance preventing clipping through geometry.
- Configurable mouse sensitivity, gamepad stick sensitivity, and axis inversion.
- Smooth rotation interpolation and camera smoothing.
- Interaction targeting: each physics frame the camera's `CameraRayCast` resolves the nearest ancestor of the hit collider that implements `display_menu(player)`, stores it in `looking_at`, and emits `looking_at_changed(previous, current)` only when it changes. The ray ignores every area in the `WATER` group, so you can look at a boat or a prop floating in a pool from the water.
- **The Player scene documents itself**: every node in `player.tscn` a reader meets carries an `editor_description`, so selecting one in the editor says what it is for. That covers the Player's own children, the camera chain, the skeleton's attachments and modifiers, the movement states and the audio groups; the ragdoll's 52 `PhysicalBone3D` children are left bare, since the bone name is the whole story, and so are the nodes that come out of Mixamo's Y Bot `.glb` rather than being put there by this scene. `tests/test_player_scene_documentation.gd` keeps it that way. Two of those descriptions earn their place: `LookAtModifier3D` bends the **Spine** towards the projectile ray's `LookAtTarget` so the torso turns to the aim (about 110 degrees either way, driven by `Player.set_look_at_target`, and only `HeldObject` and `Bow` ask for it), while `HeadLookAtModifier3D` bends the **Head** alone and is deliberately the last child of the skeleton so it applies after the spine look-at and the hand IK (about 70 degrees across and 60 up and down, driven by `Player.set_head_look_at_target`). They are not duplicates: one aims the body, the other turns the head on top of whatever the body is doing.
- **How much noise the Player makes** (`PlayerNoise`, `scripts/player_noise.gd`, a child of the Player): a
  reading from 0 to 1 that anything can listen to. Moving sets a floor: the tier is walking or sprinting, and
  the pace within it comes from how fast they are actually travelling, since movement here is root motion
  rather than a speed export. Crouching, stealth and swimming then each soften what is there, crouching by
  half. They are multipliers rather than ceilings on purpose: a ceiling meant a crouch-walk read the same flat
  line however fast you moved, so the meter looked broken while you were sneaking anywhere. One-off noises spike the reading and fall back: a landing, a slide, a swing that lands,
  a thrown object, and a gunshot, which is the loudest thing the Player has. `make_noise(amount)` is public,
  so a slamming door or a breaking pot can be just as loud.

  Everything within `hearing_range` scaled by the reading hears it, which is every `EnemyNpc` in the `Enemies`
  group inside that distance; they are told to `aggro` the Player, and `EnemyNpc.aggro` already refuses a dead
  enemy, a dead Player and one it is already hunting, so it can be shouted every sweep. Sustained noise is
  swept for every `listen_interval`, but a **one-off noise wakes listeners the moment it is made**, because a
  gunshot is loud for an instant and would often have decayed below the distance to the listener before the
  next sweep came round, so a shot could go unheard entirely. Only the authority listens, so a peer cannot wake
  another peer's enemies.
- **`NoiseMeter`** (`scenes/noise_meter.tscn`): the readout, after Breath of the Wild's. A round dark badge
  with a line across the middle: flat while silent, breaking into a waveform that is taller and busier the
  louder the Player is. It follows `PlayerNoise.level_changed` and draws nothing of its own, so the shape on
  screen and the distance the noise carries are the same number. The drawn shape is eased toward the reading
  every frame rather than stepped with it, because the reading only changes on the physics tick and stepping
  it made a continued noise look like it was stuttering; the wave also travels at a steady pace, so a change
  in loudness changes its size without also jumping its speed.
- **One target at a time** (`Camera.interaction_target`, `interaction_target_changed`): the camera picks the single thing the Action button acts on, and it is the only thing showing a prompt. What the ray lands on wins, so a crowd is settled by where the player is pointing; when the ray lands on nothing, the nearest thing in reach takes over, so walking up to something still offers it. The camera calls `hide_menu()` on the one it drops and `display_menu(player)` on the one it takes, and `action` calls `equip(player)` on it. Any scene using the player gets prompts without extra code.
- **`InteractionReach`** (`scripts/interaction_reach.gd`, on a child `Area3D` named `PlayerDetection`): arm's length around something, the volume the player has to be standing in before it will answer at all. Wire the area's own `body_entered` and `body_exited` to its `_on_body_entered` and `_on_body_exited` in the scene; it shows no prompt and reads no input, it only reports its parent to the player's camera. Its host joins the `Camera.REACH_GROUP` group, which is what tells the camera the ray alone does not reach it (the group name lives on `Camera`, so only `InteractionReach` names both: a `class_name` pointing each way stops `camera.gd` compiling the first time a project loads it), so an NPC under the crosshair across the road is not offered. It also emits `player_entered` / `player_exited` for a host that cares about proximity itself, which is how a `LockedDoor` with `stays_open` off knows to swing shut. Something with no `InteractionReach` on it, like the project's computer or skateboard, stays reachable by the ray alone out to `Camera.interaction_distance`.

  Everything that can be walked up to uses it: `TalkingNpc`, `TreasureChest`, `LockedDoor`, `CraftingStation`, `Bonfire`, `Readable` and `WaterSource` (which is its own area, being water you stand in, and joins the group directly). Each of those used to watch for the button itself, so in a crowd several prompts floated at once and the first node in scene order took the press, whoever the player was facing. They now implement `display_menu` / `hide_menu` / `equip` and leave the choosing to the camera. `Equipment` is deliberately not one of them: pickups are walk-over areas, below.
- Input is handled in `_unhandled_input`, so UI controls consume clicks and scroll first.
- While riding, the `Riding` state makes the rideable's `camera` current and this one waits; it comes back on dismount.

### 3. Equipment, Combat & Interactions (`Equipment`, `HeldObject`)
- **Weapon Classes**: 1H Swords, 2H Greatswords (with tree-logging animation), Sword & Shield, Daggers, Axes, Staffs, and Rifles.
- **Spell animation states**: the Shield group holds `ShieldPowerUp`, `ShieldSpellCast` and `ShieldSpellCasting` (Mixamo *Sword And Shield* spells), the GreatSword group holds `GreatSwordPowerUp`, `GreatSwordSpellCast` and `GreatSwordSpellCasting`, and the top level holds the one-handed standing casts `SpellCastForwards`, `SpellCastSweepingSideways`, `SpellCastSweepingUpwards` and `SpellCastUpwards` beside `StandingLocomotion`. Enter any of them with `travel_locomotion("Shield/ShieldSpellCast")`, `travel_locomotion("GreatSword/GreatSwordPowerUp")`, `travel_locomotion("SpellCastUpwards")` and so on. The one-shot casts and power-ups return to their locomotion on their own when the clip ends; the looping `...SpellCasting` channels stay until code travels back (or on to `...SpellCast` to land the spell). Nothing drives them yet: wire them from `Abilities` (`cast_started`, `ability_activated`) when a spell needs a pose.
- **Bow & Arrow Mechanics**: Aiming, string draw, charge timing, arrow trajectory, and projectile firing.
- **Pickups**: an `Equipment` in the world is a GTA-style pickup. Give it a child `Area3D` named `PlayerDetection` (a half-metre sphere works; bigger and neighbouring pickups are taken in the same step) and connect its `body_entered` to `_on_player_detection_body_entered` in the scene; the first Player to walk over it gets a copy through `equip(player)` (which now returns whether it equipped) and the area stops monitoring, so it is taken once with no prompt or button. A Player already carrying that type walks through without spending it.
- **Object Manipulation**: Pick up, carry, aim, rotate, and throw `RigidBody3D` objects or companion bodies. The throw charge bar is the `%ThrowChargeBar` node in `player_controls.tscn` (exported to `HeldObject.throw_charge_bar`); the optional `connector_scene` (a `PackedScene`, so exporters ship it) is instanced once on ready. In third person the `ItemSpringArm` follows the camera's yaw but clamps its pitch (`Camera.held_pitch_min` / `held_pitch_max`) and shortens against the world (the Player is excluded), so a held object never ends up in the ground or inside the Player however you look; the look stick and the D-pad move the object sideways, up and out (`HeldObject.get_held_offset`), and `Camera._sync_item_spring_arm` aims the arm along that offset rather than hanging the object off the arm's axis, so the arm's cast covers the line the object actually sits on and a wall beside the Player stops it there as one ahead does; a released body keeps ignoring the Player's collision for `HeldObject.RELEASE_GRACE` (0.3 s), so a throw leaves cleanly instead of being shoved out by depenetration.
- **Hit Detection & Combos**: Multi-hit attack combos and damage dispatching. `HitDetection` uses `Area3D` hitboxes, not shape queries: unarmed attacks use the `LeftHandHitbox`/`RightHandHitbox` bone attachments in `player.tscn`; a melee weapon must have a child `Area3D` named **`Hitbox`** (with its `CollisionShape3D`). Hitboxes only `monitoring` during attack locomotion nodes, and any ancestor of a hit body that defines `register_weapon_hit(equipment: Node, hit_node: Node)` is notified once per swing. Hits carry no knockback impulse. For props, give the weapon a child `AnimatableBody3D` named **`WeaponBody`** (`sync_to_physics` off, a shape along the blade, on the `Weapons` layer masking `Hittable`; `HitDetection.WEAPONS_LAYER` is 10): the equipped copy gets a collision exception with its Player and ragdoll bones, and `HitDetection` puts it on its layer only while a swing node plays, on every peer, so the server's copy of a remote Player pushes the props it simulates. `HitDetection` emits `weapon_hit(equipment, target)` once per target per swing; `player.tscn`'s `WeaponAudio` node (`EquipAudio`, `StowAudio`, `AttackAudio`, `HitAudio`, on the `SFX` bus) plays the TomMusic sword unsheath and sheath when a metal melee weapon (`WeaponAudio.BLADED_TYPES`: the axes, the dagger, the swords) joins or leaves the loadout, and nothing for anything else (a staff, a rod, a gun) unless its scene names its own, *Sword Attack 1-3* on every weapon swing node (on every peer, from the replicated locomotion node), and *Sword Impact Hit 1-3* when a weapon lands on something with `take_hit` (relayed to peers by RPC). `Equipment.equip_sfx`, `stow_sfx`, `attack_sfx` and `hit_sfx` replace those defaults per weapon; the random sets are `AudioStreamRandomizer` resources under `resources/audio/`, the clips under `assets/tommusic/fantasy_sfx/Attacks/`.
- **Look-at ownership**: `Player.set_look_at_target(target: Node3D)` is the single writer of the spine `LookAtModifier3D` (pass `null` to clear). `HeldObject` calls it on pickup/drop and `Bow` while `Bow/ArcheryLocomotion` is active.
- **Projectiles** (`Projectile`, `scenes/bullet.tscn`): every round is a `RigidBody3D` with real ballistics *and* a swept ray between physics steps, so fast bullets never tunnel through small targets such as balloons. On impact the projectile notifies the nearest ancestor of the collider that defines `register_projectile_hit(projectile, point, normal)` (or `register_weapon_hit(weapon, projectile)` for harvestables), applies `impact_impulse` to `RigidBody3D` targets, emits `hit`, then frees itself (or freezes in place for `stuck_seconds` when `sticks_on_hit`, as arrows do). Areas without a hit handler (water, weather zones) are ignored by the sweep. Launch one with `projectile.launch(origin_transform, direction, speed, shooter, weapon)`.
- **Firearms** (`Firearm`, base of `Rifle`): a gun is an `Equipment` with a child `Muzzle` (`Marker3D`, -Z is the barrel), a one-shot `FireTimer`, an optional `LaserSight` instance and `projectile_scene`; wire them through the `muzzle`, `fire_timer`, `laser_sight` exports, and optionally `fire_sfx` and `reload_sfx` (`AudioStreamPlayer3D` children): the reload plays on the shooter, while the shot's stream goes along in the round's launch data and every peer's copy of the round plays it at the muzzle through `Projectile.play_launch_sfx` (a speaker left where the round was fired, freed when the clip ends), so a shot is heard on every peer without the weapon itself being replicated. While shoot is held it fires every `fire_interval` (`automatic`), launching each round on the Player's `ProjectileRaycast` line, level with the muzzle, so rounds fly straight through the crosshair to where it lands; the camera keeps that ray on its centre line every physics frame (shoulder offset and first person included), so the crosshair is where rounds go, and detection-only areas (enemy aggro spheres, melee hitboxes) sit on no collision layer so the ray passes through them. Each gun carries `magazine_size` rounds; a shot spends one, and the `reload` action ([R]) or an empty trigger pull takes one `AmmoItem` unit for the gun's `equipment_type` from the Player's inventory after `reload_time` (`reload_sfx` optional), refilling the magazine with `rounds_per_unit` rounds (0 means a full magazine); nothing carried, no reload. The reload an empty trigger pull starts keeps its own `reload_time` on the shared timer (a round that leaves is what spaces the next by `fire_interval`), and a left click while the cursor is visible is click-to-move, never a shot; the pad trigger and the touch button shoot regardless. `reserve_rounds` reads the inventory (units times rounds) on a Player and is only an export for a gun without one; Use on an `AmmoItem` selects the kind the next reload chambers (`selected_ammo`, `ammo_selected`), `loaded_ammo` is what is in the gun, and its `projectile_scene` flies instead of the gun's own. `ammo_changed` reports both counts (on every reload, shot, pickup or drop) and the HUD's `AmmoLabel` shows them while a firearm is equipped. Every shot kicks the pad and a reload pulses it via `Controls.rumble(weak, strong, seconds)`, the one gated haptics call (no rumble on keyboard/mouse or touch) that the bow and `take_hit` use too. `fire()` returns the spawned projectile (null when the magazine is empty) and emits `fired`. `fire_sfx` is an optional `AudioStreamPlayer3D`. `Rifle` adds the firing spine emote while the Player stands still (on the move it just fires, since the emote fights the walk); the world's pistol uses `Firearm` directly. An optional `MuzzleFlash` (`scripts/muzzle_flash.gd`) under the `Muzzle` marker plays any VFX scene that has an AnimationPlayer with a `main` animation: point its `vfx` and `animation_player` at the instanced scene, turn the node so the VFX's forward axis runs down the marker's -Z, and wire the gun's `fired` to `flash` and the player's `animation_finished` to `_on_animation_finished`; the VFX stays hidden between shots so its light and glow never linger. An NPC can flash the same way: `EnemyNpc.fired` is emitted for every shot, on the authority with the round and on the other peers with `null` by RPC, so a `MuzzleFlash` under its `Muzzle` works for everyone.
- **Accuracy**: ranged `Equipment` (firearms, the bow) takes an `Accuracy` resource in its `accuracy` export: `spread_degrees` is the cone half-angle for a novice, `expert_spread_degrees` the cone at `expert_level` and above, eased linearly by the shooter's `skill_level` (`Player.skill_level`, and `EnemyNpc.skill_level` in the game's enemies, which take the same resource). Save one `.tres` per weapon (`resources/accuracy/pistol.tres`, `rifle.tres`, `bow.tres`) and tune it in the editor; `Equipment.scatter(direction)` applies it, so a weapon with no resource fires dead straight. The stray angle is uniform inside the cone, so most rounds land near the crosshair. Spread is rolled on the firing peer and the round replicates through the spawner, so every peer sees the same shot.
- **Laser sight** (`LaserSight`, `scenes/laser_sight.tscn`): a beam plus surface dot stretched from the muzzle to the aim point with `aim(from, to)`; shown while the Player focuses or shoots.
- **Bow & Arrow**: `Bow` reacts to `Player.locomotion_node_changed` (`Bow/BowDrawArrow` plays the draw sound, `Bow/BowFireArrow` duplicates the template `Arrow` child and launches it through the projectile API). `Arrow` is a `Projectile` that sticks where it lands for `stuck_seconds` (one second) before vanishing, drops its shooter exception after 0.15 s and frees itself after `lifetime` if it never lands. Every shot takes one bow `AmmoItem` from the inventory (the selected kind while any is carried, else regular arrows, else nothing flies) and fires its `projectile_scene` when it names one. Selection, reload and consumption happen on the Player's multiplayer authority only; peers receive the chosen scene through the spawner. The bow fires from the Player's projectile ray, level with the nocked arrow, on the low arc through the ray's hit point (`Bow.arc_direction`), falling back to a straight shot when the aim point is out of range; when Use selects a kind of arrow with its own scene, a frozen template copy of it is nocked in place of the plain arrow (local to the authority, cosmetic), and arrows fly without linear damping. Drawing the bow plays TomMusic's *Bow Take Out* and stowing it *Bow Put Away* (`resources/audio/bow_take_out.tres` and `bow_put_away.tres`, single-clip randomizers so an export that lists them carries the clips) through the Player's `WeaponAudio`; a shot plays the bow's `BowFireArrow` node when the scene has one, else *Bow Attack 1-2* (`resources/audio/bow_attack.tres`); `arrow.tscn` carries an `Impact` player wired to `hit`, so *Bow Impact Hit 1-3* lands on every peer that simulates the round. `arrow.tscn` also has a `Tip` `Marker3D` at the head end of the shaft (local +Y, which `Arrow` turns along its velocity in flight), so an inherited arrow scene can parent a head effect under it and have it lead the flight, sit on the string when nocked and move to the impact point when the arrow sticks.

### 4. Inventory & Radial Menu (`Inventory`, `RadialMenu`)
- The inventory ships inside this addon, at [`inventory/`](inventory/README.md): `player.tscn` instances its `inventory.tscn` as the `Inventory` node, so equipment on the skeleton, the radial quick-select, the BOTW style tabs of stacked items, Zelda style `ItemPickup`s and the `user://` save all live there. The `Pause` menu's `inventory_screen_scene` export points at its `inventory_screen.tscn` and shows an Inventory button that opens it, with Back returning to Pause; clear the path to drop the button. `extra_screen_scene` does the same for any `PlayerMenuLayer` scene of the game's, with `extra_screen_label` as the button's text (the demo world uses it for its Fish Index). `Equipment` carries `description` flavour text and an optional `model_scene` for the inventory's turning preview, and `get_details()` adds lines under the description.
- Circular weapon/tool selection menu activated by holding assigned keys or controller D-Pad.
- Quick weapon cycling (`last_weapon` / `next_weapon`).
- Extensible custom item provider callback for vehicle radios or contextual menus. Items are Dictionaries with `display_name` and `icon` (plus `item` for equipment); a `custom_item_provider` returns the same shape so the addon never knows about stations.
- `Inventory.equipment` is a typed `Array[Equipment]`; `get_equipment_by_type(type) -> Equipment`, and `equipment_changed` fires after every change (`cycle_weapon`, `equip_from_backpack`, `unequip_all`, `Inventory.equip_pickup`, which `Equipment.equip` and the walk-over pickups go through: it makes the `BoneAttachment3D` on the skeleton, duplicates the pickup onto it with the scene's offsets, and `Equipment.equip` keeps the copy as `equipment_instance`). Each `BoneAttachment3D` holds exactly one `Equipment`; stowed attachments are hidden children of `Inventory`.
- Hold detection uses the `HoldTimer` in `inventory.tscn` (`wait_time` = hold threshold); a release before timeout cycles, a timeout opens the menu.

### 4b. Abilities (`Abilities`, `Ability`)
World of Warcraft style spells on the Zelda-style controls, so an action RPG never needs a morphing action bar:
- **Tap** the `ability` action (`Q` / Left Bumper) to cast the picked ability; **hold** it to open the ability wheel and pick another. The wheel is the same `RadialMenu` scene the inventory uses (`radial_menu.tscn`, with `hold_actions` set to `ability`), and the picked ability's name shows on the Left Bumper label. The wheel holds eight spells at most; which eight is the [`Spellbook`](inventory/README.md)'s loadout, unlocked from a `SpellTree` with skill points on the Pause menu's Spells screen (`Pause.spells_screen_scene`). `Abilities.abilities` is the starting set, which the Spellbook counts as unlocked.
- `Ability` is a `Resource` any `Node3D` can cast (the Player through `Abilities`, NPCs through their own caster; `get_target` reads the Player's focus target or an NPC's `target`, and `Ability.spawn_phase` is the shared VFX/SFX/bolt playback) with `display_name`, `icon`, `icon_color` (tints the icon on the wheel and the spell screens), `cooldown`, `cast_time`, `cast_range`, `energy_cost` (mana or energy drawn from the caster's `Health` pool, never from stamina), `channel_while_moving` (off by default, so movement interrupts a timed cast as in WoW while attacks always do), `is_toggle` and `ends_on_attack`; subclass it and override `activate(player) -> bool` (return `false` to refuse, spending nothing) and `deactivate(player)` for toggles. Ship abilities as `.tres` files and list them in the Player's `Abilities.abilities` export.
- `Ability.can_cast(caster)` is checked before the cast bar starts, so a doomed cast (Heal on a full patient, a damage spell with nothing locked on) is refused at once instead of channeling for nothing; `activate` checks again when the effect lands.
- `Abilities` (a `CanvasLayer` child of the Player) handles the rest: the `HoldTimer` splits taps from holds, the `CastTimer` runs cast times while `%CastBar` in `player_controls.tscn` fills through a tween, and any `state_changed` / `locomotion_node_changed` interrupts the cast. Cooldowns are stored as end times (toggles start theirs when they end), so nothing polls. Signals: `cast_started`, `cast_interrupted`, `ability_activated`, `ability_deactivated`.
- Every `Ability` carries VFX (`PackedScene`) and SFX (`AudioStream`) for three phases: **channeling** (kept on the caster for the cast time, stopped on interrupt), **casting** (one-shot on the caster when the effect fires) and **impact** (one-shot at `get_impact_position(player)`, the caster by default; override it for ranged spells). Channeling VFX are parented to the `Abilities.hand_anchor` (the `SpellHand` bone attachment on the Player's right hand) so a charge rides the hand, bolts leave from it too, and the other VFX are instanced under the Player's `AbilityFx` node and freed after `fx_lifetime`; SFX play through the `ChannelingAudio` / `CastingAudio` / `ImpactAudio` players there on the `SFX` bus. Phases are played on every peer through an authority RPC.
- **Cast animation**: set an ability's `cast_style` (`FORWARD`, `UPWARD`, `SWEEPING_SIDEWAYS`, `SWEEPING_UPWARD`, `POWER_UP`) and the Player picks the clip for whatever it holds through `Ability.get_cast_state(group, channeling)`: with a shield or greatsword a timed cast holds the group's `...SpellCasting` channel (`cast_started`) and the effect landing plays `...SpellCast`, or `...PowerUp` for the power-up style (`ability_activated`); unarmed the landing plays the matching standing one-handed clip (`SpellCastForwards`, `SpellCastUpwards`, `SpellCastSweepingSideways`, `SpellCastSweepingUpwards`; power up borrows the upward cast) while the channel holds the *Ready To Cast Spell* emote on the upper body (the same pose a carried object uses); bows, guns and boxing play nothing. The clips return to locomotion on their own, an interrupt (`cast_interrupted`, which a cast that fizzles when it lands also emits, such as Heal at full health or Firebolt with nothing locked on) drops the channel pose, and the cast's own clips never count as a locomotion change that interrupts it. The three signals are connected to the Player in `player.tscn`.
- **Elements**: `elements` is a set of flags (`Fire`, `Water`, pick any mix) that the impact lets loose on the world within `element_radius`: Fire lights every `GrassField` (`ignite_at`, spreading for `element_fire_duration`) and `BurnableGrass` patch there, the way the thrown torch does; Water douses them (`GrassField.douse_at`). `Ability.apply_elements` runs from `spawn_phase` with the impact VFX, so every peer and NPC casters get it too. Firebolt carries Fire. `Ability.ignite_grass(tree, at, radius, duration)` is the Fire half as a static, for anything that is not a spell (a burning projectile).
- **Toon filter** (`ToonFilter`, `scenes/toon_filter.tscn`, `assets/shaders/toon_filter.gdshader`, `scripts/cel_compositor_effect.gd`): toon shading under the Player's `Camera3D` with a `mode` of `OFF`, `NEWSPAPER`, `CEL`, `BINBUN` or `BOTW`. `NEWSPAPER` is a full-screen quad whose spatial shader posterises the opaque scene into `bands` luminance steps (hue and saturation kept) and draws `outline_color` lines where the depth buffer jumps, with `strength` to dial it down; it reads only the screen and depth textures, so it compiles in Forward+, Mobile and Compatibility, and draws before every CanvasLayer (HUD untouched) and before every other transparent object. `CEL` puts a `Compositor` with one `CelCompositorEffect` on the camera: a compute shader run after the transparent pass that snaps luminance to `bands` (3) hard perceptual levels, pushes saturation by `saturation_boost`, and inks `outline_color` `outline_thickness` (2 px) lines wherever the depth jumps past `depth_threshold` or the normal-roughness buffer's normal turns past `normal_threshold`, so interior creases get ink too; far-plane pixels are skipped so the sky keeps its gradient, and transparent objects are banded but not outlined. It needs the Forward+ compositor: `is_cel_available()` checks `RenderingServer.get_current_rendering_method()`, `cycle()` skips it elsewhere, and the effect stays inert without a `RenderingDevice`. `BINBUN` is no screen pass: it overrides every opaque `BaseMaterial3D` surface in the tree with Binbun's stylized shader (`assets/shaders/binbun_stylized.gdshader`, a copy of the Ultimate Toon Shader, through the `resources/binbun_toon.tres` template in `binbun_material`), each copy wearing the surface's own albedo texture and colour, so light is stepped per object (3 steps) with a tinted shadow and a soft rim; `ShaderMaterial` surfaces (water, grass, the sky, VFX), transparent surfaces and meshes with a `material_override` keep their own, meshes added while it is on get it through the tree's `node_added`, and every other mode (or leaving the tree) puts the originals back. It runs in every renderer. `BOTW` takes the same material-override path (`override_template()` picks the template for the mode) with `botw_material`, `resources/botw_toon.tres` on `assets/shaders/botw_toon.gdshader`, the addon's own Breath of the Wild look: a lit band in the sun's colour and a shadow band in `shadow_color` (a sky blue, added for the directional light only so point lights never stack it), the edge between them at `shadow_threshold` wobbled by `warble_amount` of world-space value noise moving at `warble_speed` (the game's warbly terminator), a `specular_softness` soft highlight on the lit band, and a `rim_color` fresnel rim at `rim_backlight` strength when the surface is seen against the light and `rim_lit` on its lit side, never inside a shadow. The `toggle_toon` action (`F6`) cycles the modes; the **Toon shading** option in Video settings picks one (Cel greyed with a tooltip off Forward+, the touch button skips it); `mode_changed` keeps the option in step and the choice is saved as `PlayerSettingsResource.toon_mode` (an older `toon_enabled = true` loads as Newspaper). Local only, never replicated.
- **Chat** (`scenes/chat.tscn`, `ChatWindow`): an embedded, movable and resizable window on the local Player only. Enter (`chat` action) opens the input row, Enter or Send submits, Escape cancels; messages travel by RPC so ENet and Steam sessions both carry them, with the Steam persona name or `Player <id>` as the sender. Lines starting with "/" run locally: `/help` lists commands and `/teleport x y z` warps the Player; add a command with one line in `ChatWindow.commands`. The window fades to `idle_alpha` after `idle_seconds` and comes back while hovered or while a message arrives; while the input is open `Player.is_typing` blocks every gameplay action, and the window hides while a menu is up. Its position and size persist in `PlayerSettingsResource.chat_rect`.
- **Throwing**: `HeldObject` also throws inventory items. With nothing in hand, `throw` (`T` / Right Bumper) takes the equipped `Equipment` if its `is_throwable` is set (`Inventory.forget_equipment` unequips it), else `Player.selected_throwable` or the first `Item` with `throwable`, and puts its model in `HeldObject.throw_hand` (the `HeldItemConnector` bone attachment) while the usual charge runs; release throws it as `scenes/thrown_item.tscn` (`ThrownItem`) at `throw_speed` times the charge, through the `ProjectileSpawner` (`fire` with extra launch data) so every peer gets the body. On its first landing the server's copy calls `take_hit(throw_damage)` on what it hit and `place`s an `ItemPickup` (or the equipment's scene) where it lies, despawning the body everywhere. Pausing mid-charge puts the item back.
- **Seeker wheel**: hold `seeker` (`I` / D-pad Up) for a second `RadialMenu` (`scenes/seeker_wheel.tscn`, `Player.seeker_wheel`). Aiming with a firearm, or holding a bow with focus held or the string drawn, it lists the carried ammunition kinds for that weapon and releasing on one selects it exactly as Use does (`Inventory.use_item`), so the badges and the nocked arrow follow; otherwise it lists the throwable items and releasing on one sets `Player.selected_throwable` for the next throw. It stays closed with nothing to pick, never opens on a puppet, and a carried object keeps D-pad Up for its own rotation. The HUD's Seeker hint reads Arrows or Ammo only while the wheel would list them, that is while the bow or the gun is aimed (`PlayerControls.seeker_label_text` asks `SeekerWheel.get_aimed_weapon`), and Seeker otherwise; it follows the aim through `Player.locomotion_node_changed` (wired to `PlayerControls` in `player.tscn`) and the focus action, re-applying the state's labels only when the answer changes. A world prompt's Action label ("Pick Up", "Get In") lives on `Controls.prompt_action_label` while the prompt is up, so those refreshes keep it; `ActionPrompt.hide_for` gives it back, unless another prompt has taken the label since.
- `target_mode` picks where impact lands: `SELF` (the caster) or `FOCUS` (the locked-on `Focus` target; with nothing locked, whatever the crosshair's projectile ray points at that has `take_hit`, found by `Ability.get_aimed_target`; with nothing there, the aim point along the ray). So a damage spell fires forward like a projectile without a lock, action-RPG style, and a lock only makes it home. Override `impact(player, target)` to apply damage or buffs to the target when the impact lands.
- Set `projectile_speed` above 0 and the casting VFX/SFX fly to the target as a `SpellProjectile` (`spell_projectile.tscn`) instead of a bullet or arrow: a plain `Node3D` bolt with no physics that always arrives, homing on a moving target by default (`projectile_homing`). Impact (and `impact()`) lands when the bolt arrives, WoW style; every peer flies its own copy and only the caster's authority lands the impact.
- Included abilities (`resources/abilities/`): **Stealth** (`StealthAbility`, instant toggle) sets `Player.is_stealthed`, which swaps every mesh under the skeleton for a ghost of itself (`assets/shaders/stealth.gdshader`: the surface's own colour and texture washed pale and tinted cold, drawn after a `depth_prepass_alpha` pre-pass so arms never show through the torso as plain `transparency` does) and tweens its alpha down to `1 - stealth_transparency` over `stealth_fade_time`, restoring the original materials once the fade out lands; the flag is replicated so other peers see the fade, and it makes followers lose the Player; any melee swing, bow shot or firearm `fired` ends it. **Heal** (`HealAbility`, 1.5 s cast) restores health. Heal casts upward with the TomMusic *Waterspray* channel and *Wave Attack* cast sounds, Stealth sweeps sideways with *Ice Freeze*; both still ship without VFX. The sounds live in `assets/tommusic/fantasy_sfx/Spells/`.
- Only the multiplayer authority reads input and casts; effects that others must see belong on replicated Player properties, as Stealth does.
- `Player.slow(factor, seconds)` is an RPC that lands on the owning peer like `take_hit` and scales the movement wish by `movement_scale` for a while, so a slowing spell walks the Player where it would run; a newer slow replaces an older one and runs its own timer. Give any other target a `slow(factor, seconds)` method and a slowing `DamageAbility` reaches it the same way.

### 5. Multi-Platform Contextual Controls (`PlayerControls`)
The HUD itself is the [Controls addon](https://github.com/kirbycope/godot-controls), a separate repository, because
most projects want on-screen input hints without a player controller. What lives here is `PlayerControls`
(`scenes/player_controls.tscn`), a scene inheriting the addon's `controls.tscn` that names every button after this
addon's actions and adds the four readouts only a player has: the throw charge bar, the cast bar, the boss bar and the
ammo count. `PlayerControls` is a `@tool` like the HUD it extends, so the editor preview and `hud_scale` run for
`player_controls.tscn` and `player.tscn`; the throw charge bar, the cast bar and the ammo count sit in a `BottomCenter`
cluster anchored bottom-centre and the boss bar in the HUD's own `TopCenter`, so all four scale with the corners.
- Adaptive input icons and button hints supporting:
  - **Keyboard & Mouse**
  - **Microsoft (Xbox)**
  - **Sony (PlayStation)**
  - **Nintendo (Switch)**
  - **Touch Screen**
- Real-time contextual action labels that adapt dynamically to the player's active locomotion state.
- Every button is a slot with an exported action name, set on the instance in `player_controls.tscn` (`action_button_0 = &"action"`, `action_axis_5_plus = &"shoot"` and so on) rather than hardcoded, which is what lets the same HUD serve a project with no Player. Each slot registers the pad button it is drawn on when the project has not defined that action, and `PlayerControls.PLAYER_ACTIONS` adds what a pad button cannot describe: the keyboard keys and mouse buttons behind those slots, plus `reload`, `broadcast`, `chat`, `debug` and `toggle_toon`, which have no button on the HUD at all. So the addon stays drop-in with no `project.godot` edits. Actions a project already defines are left untouched; the engine's built-in `ui_*` actions are only extended (joypad A / D-pad).
- Device button textures come from per-vendor `Texture2D` lookups (`_vendor_textures`) applied in one loop; keyboard-only and joypad-only hints toggle visibility as a group, and `update_input_ui()` runs from the `current_input_type` setter before `input_type_changed` is emitted.
- **Control schemes** (`PlayerControls.ControlScheme`, picked with `Player.control_scheme`): which game's pad the face buttons are laid out like, and what Focus does. `ZELDA`, the scene's own, is A Action, B Sprint, X Attack, Y Jump, with Focus locking on to a target. `GTA` is A Sprint, B Attack, X Jump, Y Action, and Focus is a free over-the-shoulder aim with anything in hand (`Player.lock_on_enabled()` is false, so `Focus` acquires nobody and the camera keeps the aim FOV and shoulder offset for as long as focus is held instead of swinging behind the Player). `PLATFORMER` is A Jump, B Sprint, X Attack, Y Action, the bottom-button jump of a Mario or a Sonic, with Focus locking on. The keyboard keys, the shoulders, the triggers, the sticks and the d-pad are the same in all of them. `PlayerControls.SCHEME_SLOTS` is the table, `apply_control_scheme()` swaps the slots live: each face button comes off the action it stood for, goes on to its new one, the resting labels follow, and a project that bound an action for itself in `project.godot` is left alone. Whatever a state or a world prompt writes on "the Action button" or "the Jump button" follows the action, not the physical button (`Controls.prompt_action`, `action_label`, `action_button` in the controls addon), so "Pick Up" lands on Y in the GTA layout and "Climb" on A in the platformer one. The Video settings menu has a `Scheme` option (`Default`, `Zelda`, `GTA`, `Platformer`; `PlayerSettingsResource.control_scheme_index`) that overrides the scene's export for the player who picked it.
- **A second local player** (`Player.input_device`): a Player on a pad of its own polls through `Player.is_action_pressed`, `get_action_strength` and `get_vector`, which resolve the action's joypad bindings against that pad (`Input.is_joy_button_pressed`, `Input.get_joy_axis`); every polled action read in the controller goes through them, and a lone Player (device -1) reads the whole input exactly as before. Events are filtered by the view the Player sits in (`PlayerView`, section 13), so the action names never change and nothing is rebound. A rideable or a prop of a game's that polls `Input` directly answers to every pad at once; read through the Player to serve one view.

### 6. Stamina System (`Stamina`)
- Stamina is the Player's movement energy (sprinting, climbing, swimming, gliding; sprinting with a pistol or rifle costs nothing, since their blend spaces stop at the run clip and sprint buys no speed); abilities cost mana from the `Health` child's energy pool instead, so casting never touches the stamina wheel. Mana regenerates only out of combat: enemies call `Player.hunted_by(path, hunting)` (an RPC to the owner) when they start and stop targeting the Player, and `Health.regen_paused` holds the pool while `Player.hunters` is not empty. Hit points also live on `Health` (see 6c). `Player.take_hit(damage, from)` (an RPC that lands on the owning peer) costs health, shoves the Player away and rumbles the pad; `Player.heal(amount)` (an RPC to the owner) refills health, and Players are `Focusable`, so the Heal ability lands on a locked-on fellow Player instead of the caster; `register_projectile_hit` makes enemy arrows and bullets (`Projectile.damage`) count. At zero health the Player ragdolls and the `RespawnTimer` brings them back at the spawn point with full health.

### 6c. Health, Head Bars & Boss Bar (`Health`, `StatusBars3D`, `Boss`, `ProgressBar3D`)
- `Health` (`scenes/health.tscn`) is a drop-in child for any character: `max_health`, `health`, an optional `max_energy` pool with `energy_regen` on its `RegenTimer` (the Player ships with 100 mana; the spellcaster NPC has its own pool), `damage()`, `heal()`, `spend_energy()`, and `health_changed` / `energy_changed` / `damaged` / `died` signals. Replicate `Health:health` (and energy) from the authority and puppets follow.
- `StatusBars3D` floats a health bar (green for Players, red for enemies) and a blue energy bar over the head; wire `Health.health_changed` and `Health.energy_changed` to `set_health` / `set_energy` in the scene; the Player's blue bar is its mana. Bars hide while empty or full. `ProgressBar3D` is the billboarded world-space bar underneath (float values, per-instance colour, `always_visible`).
- `MeleeHitbox` (`scenes/melee_hitbox.tscn`) is an attack volume for NPC weapons: parent it to the bone attachment holding the weapon, set `attacker` and `damage`, and call `swing()` when the animation reaches the strike; it stays live for `active_seconds` and hurts each body it overlaps once per swing through `take_hit`, so a hit lands because the weapon touched the target.
- `Boss` (`scenes/boss.tscn`) shows the owner's `boss_name` and health on the HUD boss bar (`%BossBar` in `player_controls.tscn`, Breath of the Wild style) of the player it is fighting: the authority calls `engage(peer_id)`, `target_peer` replicates through its own synchronizer, and the peer owning that player shows the bar through `PlayerControls.show_boss` / `update_boss` / `hide_boss`.
- Modular drain and recovery rates for sprinting, climbing, swimming, diving (breath meter), and gliding.
- Exhaustion state with heavy-breathing locomotion recovery.
- Inspector toggles to enable or disable stamina constraints. The hide delay is the `Stamina/Timer` node's `wait_time` in `player.tscn` (its `timeout` is wired to `hide`).
- **WeatherFX interop (optional)**: When the `weather_fx` addon is present, precipitation is read via a soft lookup (`Player.get_precipitation_strength()`) — the addon remains fully functional without it. The player scene root belongs to the `Player` group so interoperating addons can find it with an O(1) group lookup.

### 6d. Checkpoints, Death & Saving (`Checkpoint`, `KillZone`, `DeathScreen`, `SaveGame`)
- **Death flow**: zero health drops the Player into the ragdoll (`Player._on_health_died`), the `DeathScreen` under the Player (`scenes/death_screen.tscn`, wired to `Health.died` and `Player.respawned` in `player.tscn`; `title` and `subtitle` are exports) darkens the screen and counts the `RespawnTimer` down, and `Player.respawn()` brings them back at `Player.respawn_transform` with full health and emits `respawned`. `respawn_transform` starts as the spawn point; the pause menu's Unstuck goes there too.
- **`Checkpoint`** (`scenes/checkpoint.tscn`): an `Area3D` with a beacon. A Player walking through takes it as their respawn point (`Player.set_checkpoint`, `checkpoint_changed`), is healed when `heals` is on, and `activated(player)` fires; `respawn_point` is where they come back (the area itself when empty), `one_shot` fires once per Player. Only the Player's own peer answers, so nothing replicates.
- **`KillZone`** (`scenes/kill_zone.tscn`): the bottom of the world. A Player that falls in dies through the ordinary flow and comes back at their checkpoint; with `lethal` off they are only put back there. Anything else with a `Health` (an enemy, a companion) is killed on its own authority. A Player riding or flying through is left alone. It checks the body is really inside its box before acting, because the physics step reports a shape that was switched back on where it last was (the ragdoll ending on a respawn) a step late.
- **`SaveGame`** (`scenes/save_game.tscn`): drop one in the world. Every node in the `Saveable` group that implements `save_state() -> Dictionary` and `load_state(state: Dictionary)` is written to `save_path` (`user://savegame.tres`) as a `SaveGameData` under its path from the SaveGame's parent, and read back into whichever of them are still there. The Player saves itself (position, checkpoint, health, energy, stamina, the whole inventory through `Inventory.make_save()`, and the quest log); `EnemyNpc` saves its position, pools and whether it is dead (a saved corpse dies where it fell, a saved fighter is revived); a world adds its clock, weather and whatever else by joining the group. `save_game()` is the pause menu's Save Game, `load_game()` its Load Game (both shown only while a SaveGame is in the scene, Load enabled while the file exists), `autosave_interval` writes on the `AutosaveTimer`, and `save_on_checkpoint` writes as each `Checkpoint` is taken. A title screen's Continue sets `SaveGame.load_requested` before the world loads; the SaveGame loads once the local Player is in (through `player_spawner`, or on ready without one). Over the network only what this peer owns is saved or loaded.

### 6b. Riding, Focus & Water Splash (`Riding`, `Focus`, `WaterSplash`)
- **Rideable contract** (duck typed; the addon depends on no rideable). Methods: `mount(player)` and `dismount(player)` on entering and leaving the state, `ride(player, delta)` every physics frame, optional `ride_input(player, event)`, `locomotion_node_changed(player, state_path)` and `get_contextual_controls(input_type)`, which returns label names to text (`{"key_k": "Dismount"}` goes on `Controls.key_k_label`; unknown names are dropped). Optional properties the state reads: `blocks_hands` (weapons and items stay holstered, the crosshair hides), `disables_collision` (the Player's collision shape is off while ridden, for a seat inside a body), `seat` (a `Node3D` the state pins the Player to, transform and all, after every ride, so they turn and move with the rideable in the same frame while their camera keeps the view it had, as on foot; the rider faces and their camera looks along the seat's -Z, Godot's forward, so point the seat the way the rideable travels, and they keep that facing when they get off; the Player is not reparented, so the spawner, the synchronizer and every path to it keep working; the horse uses it, the car positions its driver itself around the enter animation), `camera` (a `Camera3D` the state makes current; without one the Player's own camera stays the view and keeps looking around), `mount_animation` / `dismount_animation` (locomotion nodes the state plays on the way on and off, during which the rideable is not ridden; `player.dismount(true)` skips the get-off clip, a bail out) and `input_type` (kept equal to the Player's current `Controls.InputType`, so the rideable resolves its own keyboard and pad action exports). The Player's step-up ray is off for every ride, since the rideable owns the ground contact. Animations stay in the Player: the rideable emits `locomotion_requested(state_path, immediate)`, `locomotion_blend_requested(path, value)` and `jump_requested`. Beyond the contract a rideable uses the Player as a `CharacterBody3D` plus its movement API (`orientation`, `model_pitch`, `rotate_model_to_direction`, `turn_model_toward_direction`, `update_movement_and_rotation`, `warp_to`, `player_model`, `player_input`, `camera` and the state flags). `ride_started` / `ride_ended` signals and the `riding` reference tell everyone else what is being ridden. `ActionPrompt.show_for(player.controls, "Get In")` names the Action button while a prompt is up and `hide_for(player.controls)` gives the label back.
- **Focus**: candidates are bodies in the `Focusable` group overlapping the `TargetDetection` area; a target that leaves the area is dropped after `Focus/TargetLossTimer` elapses. Lock-on is disabled while a firearm is equipped (`Inventory.equipment_changed`). Put a `Marker3D_FocusTarget` on a body to set its focus point. While locked on, the camera aims at the target in the Player body's own frame, so it stays on the target after a ride or a rotated spawn instead of swinging off by the body's yaw.
- **WaterSplash**: `emitters: Array[GPUParticles3D]` is exported from `water_splash.tscn`; the splash frees itself once every emitter's `finished` signal has fired.

### 7. Debug HUD & In-Game Settings (`Debug`, `Settings`, `AudioSettings`, `VideoSettings`)
- **Debug Telemetry**: State, equipment, perspective and FPS read-outs refreshed at 10 Hz by a `Timer` in `debug.tscn` while the HUD is visible (toggle with `F3`; only the multiplayer authority reacts). The click-to-move target is marked by the hidden `NavigationMarker` sphere in the scene, which hides itself from `Player.navigating_changed`.
- **Menu base class** (`PlayerMenuLayer`): `Pause`, `Settings`, `AudioSettings`, `VideoSettings` and `LobbyManager` extend it. It owns `player`, `focus_on_show` (the control focused when the menu opens, set in each scene), `show_menu()`/`hide_menu()` (which set `player.is_paused` and the mouse mode) and closes on the `start` action. Subclasses only hold their button handlers. A menu with `pauses_world` on (`pause.tscn` sets it) also pauses the scene tree, but only when the Player plays alone (`is_single_player()`: no multiplayer peer, or a connected host nobody has joined; a peer still connecting never pauses, a client never pauses the world). Menus run with `PROCESS_MODE_ALWAYS`, a menu opened from the paused one (Settings, the inventory) keeps the pause until it closes, `hide_menu()` and the menu leaving the tree always resume, and a peer joining while the host is paused resumes the world with the menu still up so the newcomer's world runs.
- **Split Settings Menu**:
  - **Audio Settings** (`AudioSettings`): Volume sliders and step buttons for `Dialog`, `Menu`, `Music`, and `SFX` buses. Slider `value_changed` applies the bus volume immediately; the file is written on `drag_ended` and when the menu closes, not on every tick. The bus name and the slider are bound in the scene's `[connection]` blocks, so one handler serves all four rows. With Steam loaded the Audio settings also show a Voice Chat Volume row and a Mute voice chat toggle; both drive the `Voice` bus (added to `default_bus_layout.tres` and created by `Audio` when a project lacks it) and persist locally in `PlayerSettingsResource.voice_volume` and `voice_muted`.
  - **Video Settings** (`VideoSettings`): Controls for `VSYNC`, `MSAA`, `SSAA`, `FXAA`, `SSRL`, `TAA`, and `FSR`. `SSAA` and `FSR` both drive the viewport's 3D scaling, so picking one resets the other (control and saved value). The MSAA/SSAA value tables live only in `PlayerSettingsResource`.
  - **UI Scale** (in Video settings, `PlayerSettingsResource.ui_scale_index`): `Auto`, `100%`, `125%`, `150%` or `200%`. It sets the window's `content_scale_factor`, which scales everything drawn on the canvas (the menus, the inventory, a game's own panels) whatever the project's stretch mode is, so a project that draws pixel for pixel still gets readable menus on a 4K or Retina screen. `Auto` is the window's shorter side over 800, the height the menus were laid out for, never below 1, and it re-measures whenever the window is resized. The on-screen controls are not affected by it: the controls addon measures its buttons through the final transform and keeps its `button_fraction` of the screen whatever the menus are scaled to.
  - **Scheme** (in Video settings, `PlayerSettingsResource.control_scheme_index`): `Default`, `Zelda`, `GTA` or `Platformer`, the control scheme of section 5; `Default` keeps whatever the scene set on `Player.control_scheme`.
  - **Controls** (in Video settings, `PlayerSettingsResource.hud_mode`): `Auto`, `Shown` or `Hidden`. `Shown` draws the whole HUD; `Auto`, the default, draws the whole HUD only while the device in hand is a touchscreen. Otherwise (`Hidden`, or `Auto` on a keyboard or a pad) the HUD switches to the controls addon's `contextual_only` mode: only the buttons whose label means something right now are drawn (Pick Up on Action beside a pickup, Climb on Jump at a wall, the fishing buttons with the rod out), and they pop in and out as the context changes, the way Breath of the Wild does it. The node itself is never hidden. `Player.apply_hud_visibility()` puts the rule back after a game or a menu has taken the HUD (the retro computer), and `Player.hud_mode_override` lets a scene force a mode: the demo scenes set `SHOWN` so every button is on screen.
- **Persistent User Settings**: All audio and video preferences are saved to and loaded from `user://settings.tres` via `PlayerSettingsResource`. `load_or_create()` returns one shared instance, so the player applies it once at startup and every menu edits the same object.
- **Multiplayer Animation Sync**: `PlayerSynchronizer` replicates `sync_locomotion_node` (the full `Group/Node` locomotion path) and `sync_blend_position`; puppets travel their AnimationTree to that path and write the blend position into whichever blend space is current.

### 8. Audio Component System (`Audio`)
- Modular 3D audio subsystem (`audio.tscn` paired with `audio.gd`) encapsulating surface-aware footstep audio streams (`Grass`/`Dirt`, `Stone`, `Wood`, `Water`, `Slide`).
- Dynamic surface detection via physics collider group tagging and raycasting.
- Centralized volume scaling: `set_sfx_volume` covers the footstep players and every `vehicles` group member with a `set_sfx_volume(value)` method; `set_music_volume` covers every node in the **`radio`** group with a `set_volume(linear: float)` method. Add your radios (e.g. `RadiOtPlayer3D`) to the `radio` group for the music slider to reach them.
- Creates the `Dialog`, `Menu`, `Music`, and `SFX` audio buses at runtime when your project's bus layout lacks them, so the audio settings menu works without editing `default_bus_layout.tres`. Footstep players play on `SFX`.

### 9. Steam Lobby UI (`LobbyExplorer`, `LobbyManager`) & Loading Screen (`Loading`)
- Optional and self-contained: the lobby scenes reach Steam only through `Engine.has_singleton("Steam")` and the `/root/Steamworks` autoload when present, and ship with plain `TextureRect`/`Label` nodes and Kenney icons, so the addon has no dependency on GodotSteam or GodotSteamKit and still exports to web. Without Steam the UI reports "Steam unavailable" and disables its buttons.
- `lobby_explorer.tscn` lists public lobbies and hosts/joins one. Set its exports on the instance in your project: `world_scene` (loaded after hosting/joining), `title_scene` (loaded by BACK) and `footer_text` (shown with the current year). `lobby_manager.tscn` (child of the Player, opened from the pause menu) lists members with avatar, host badge, profile/achievements shortcuts and, for the host, promote/kick; kicks go through Steam's lobby chat and the list refreshes from Steam's `lobby_chat_update`/`lobby_data_update` callbacks.
- `loading.tscn` (`Loading`) shows a tip, progress bar and dependency log while `ResourceLoader` loads a scene in a thread; `load_scene(path)` ignores a second request while one is in flight and only polls while loading.

---

### 10. Multiplayer (`SteamPeer`, `PlayerSpawner`, `ProjectileSpawner`, `SyncedBody`)
- **Session**: drop a `SteamPeer` node into the world. When the world loads inside a Steam lobby it hosts if the local user owns the lobby and connects to the owner otherwise (`SteamMultiplayerPeer`, reached only through the Steam singleton, so web exports stay inert). Call `host()` yourself after creating a lobby locally.
- **Players**: a `PlayerSpawner` (`MultiplayerSpawner`) with `player_scene` set to `player.tscn` or a scene inheriting it spawns one player per peer under `spawn_path`, named by peer id, and frees it on disconnect. `Player._enter_tree` takes its multiplayer authority from that name, so input, aiming and firing run only on the owning peer while `PlayerSynchronizer` replicates transform, locomotion path and blend position to everyone else, along with the stance flags (`is_shooting`, `is_aiming_bow`, `is_drawing_arrow`, `is_firing_arrow`, `is_mining`, `is_logging` read the synced value on a puppet), `is_stealthed` (applied on ready for a late joiner) and `display_name`, the Steam persona over the head, so every peer reads it. Every peer's copy of a Player carries the same equipment: the authority's `Inventory` sends its scene paths after every change and to each peer that connects (`_sync_equipment`, an authority RPC), and the puppet rebuilds the pieces on its skeleton, visual only, so weapon stances, aiming, bow draws and footsteps (the ground raycast, not `is_on_floor()`, which only `move_and_slide()` computes) show there. Voice packets, the speaking indicator and chat lines are authority RPCs too. `local_player_spawned` hands the world the player it controls. In the editor the spawner (a `@tool`) shows the Player's model at `spawn_point` (or the `spawn_path` container's origin) so you can build the map around them; it is an internal child that is never saved and never exists in the game, and it refreshes when `player_scene` or `spawn_point` changes.
- **Projectiles**: a `ProjectileSpawner` in the `ProjectileSpawner` group makes `Firearm.fire()` and `Bow.fire_arrow()` (with `arrow_scene`) go through `spawner.fire(scene, origin, direction, speed, shooter, weapon)`. Clients ask the host over RPC; the host spawns with a custom `spawn_function`, so every peer instantiates and launches an identical round from the same data and resolves its own hits. Rounds sit on no collision layer and ignore each other. `ProjectileSpawner.place(scene, position)` spawns any scene at a world point on every peer through the same `spawn_function` (positions are relative to `spawn_path`), and `ProjectileSpawner.ignite(position, radius, duration)` lights the grass on every peer over an authority RPC; only the server's call does anything, since spawned rounds are the server's. `ProjectileSpawner.find_for(node)` returns the spawner of that node's multiplayer session.
- **World objects**: `SyncedBody` is a `MultiplayerSynchronizer` for physics props; peers that do not own the body freeze it kinematically and take the replicated transform. `resources/rigid_body_replication.tres` and `resources/character_body_replication.tres` are ready-made replication configs. Hit-driven state such as balloons and harvestables should resolve on the server and replicate back (`register_projectile_hit` → RPC to the server → `call_local` broadcast).
- **Signals and spawn state**: `Player.state_changed` only fires once the node is ready, because the spawner applies replicated spawn state while a puppet's children are still entering the tree.

The lobby owner hosts and everyone else connects to them through `SteamPeer`, which decides that by asking
whether a session already exists rather than whether the tree has a multiplayer peer: Godot gives every tree an
`OfflineMultiplayerPeer` from the start, so the latter is always true. Asking it used to make both paths
return early, with the lobby joined on both machines and no session ever formed.

The camera a peer controls claims the view when it is ready; the scene marks no camera current, so a remote
player's copy spawning later never takes over the view for even a frame.

`Player.emote_spine_blend` is how far the emote layer is blended over the spine, and it replicates: a throw, a
draw or a wave raised on the authority shows on every copy's upper body. Every writer sets the property rather
than the tree parameter.

### 11. NPCs (`FollowerNpc`, `EnemyNpc`, `NpcCaster`, `TalkingNpc`)
- **`FollowerNpc`** (`scripts/follower_npc.gd`): a `CharacterBody3D` that follows its `player` over the navigation mesh at `follow_distance` (with `follow_slack` so it never shuffles at the boundary, `walk_speed` inside 1.5 m of it), swims in water areas (`in_water_area`, set by the world's water signals), takes knockback from fast rigid bodies, pushes slow ones, ignores a stealthed Player, and can be slowed (`slow(factor, seconds)`, relayed to the server). With no `player` it stands where it is.
- **`EnemyNpc`** (`scenes/enemy_npc.tscn`, the Quaternius mannequin with Mixamo clips): idles until struck or approached inside its `AggroArea`, hunts over the navmesh, attacks in `attack_range` with a `MeleeHitbox` swing whose weapon must touch you, a `projectile_scene` (with an `Accuracy` and `skill_level`), or the abilities its `NpcCaster` holds; takes headshots, burns (`burn`, `extinguish`), leashes back to its post past `leash_distance` and heals there, and dies into its ragdoll. `is_boss` puts it on the HUD boss bar. Locomotion is a blend space fed by root motion. A game gives it a weapon on `WeaponAttachment`, and a fire under `BurnVFX` (the host project's `scenes/enemy_npc.tscn` inherits this one and hangs the weather addon's flame there; the addon itself burns without one). It replicates health, death, animation state and burning from the server and relays hits from clients, and it saves with the game (section 6d).
- **`NpcCaster`** (`scripts/npc_caster.gd`): casts `Ability` resources for an NPC: the first ready ability whose target is in cast range and line of sight, standing through its cast time; heals wait for low health; phase VFX and SFX play on every peer.
- **`TalkingNpc`** (`scenes/talking_npc.tscn`): somebody to talk to. Being the camera's chosen target is also when they notice you: `notice(player)` turns the body on the spot to face you, yaw only (`faces_talker`), and points a `HeadLookAtModifier3D` on the `Head` bone at your own `HeadAttachment` (`head_tracks_player`). The split is deliberate. The body carries the turn and the head carries the pitch, so an NPC looking at a player on a step above them tips their head instead of leaning the whole torso back, and the modifier's limits mean a target behind them is not followed all the way round. It is also the clearest possible answer to "which one am I about to talk to", since the chosen NPC is the one that looks up at you. `notice(null)` lets go. Get within arm's length and look at them, and the `ActionPrompt` offers `Talk` (`prompt_label`); Action opens their `dialogue` in the Player's `DialogueScreen` with `display_name` as the speaker, and they face the talker until it ends (`talked_to` fires). Left with no `player` they stand; given one they follow like any `FollowerNpc`. The walk and run blend replicates.

### 12. Dialogue & Quests (`Dialogue`, `DialogueScreen`, `Quest`, `QuestLog`, `QuestScreen`)
- **Resources**: a `Dialogue` is `DialogueLine`s in order. A line has a `speaker` (empty takes the talker's name), `text`, `choices` (`DialogueChoice`: `text`, `next`, and what it does), `next` (the following line by default), `ends_dialogue`, `entry` (off, it is only reached through `next` or a choice), a `condition` on a quest (`QUEST_NOT_STARTED`, `QUEST_ACTIVE`, `QUEST_COMPLETE`, `OBJECTIVE_DONE`), and `starts_quest` / `progresses_objective`, which happen as the line is shown. The dialogue opens on the first entry line whose condition holds and goes on to the next that does, so one resource covers an NPC before, during and after a quest. A `Quest` has an `id`, `title`, `description`, `objectives` (`QuestObjective`: `id`, `description`, `required`) and `rewards` (items by count).
- **`DialogueScreen`** (`scenes/dialogue_screen.tscn`, a `PlayerMenuLayer` under the Player as `Player.dialogue_screen`): the box at the bottom. `start(dialogue, talker, speaker_name)` opens it and pauses the Player as a menu does; a line types out at `characters_per_second`; Action (or Confirm) reveals the rest, then goes on; choices are focused buttons, so the sticks, the d-pad, the mouse and a finger all pick one; the bottom-action label reads Continue or Choose through the HUD's prompt label; the pause button ends it. `dialogue_started`, `line_shown`, `choice_made` and `dialogue_ended` are for a game that wants to know.
- **`QuestLog`** (a `Node` under the Player as `Player.quest_log`): `start(quest)`, `progress(objective_id, amount)` from wherever the game notices something (a felled tree, a landed fish), `get_status`, `is_active`, `is_complete`, `is_objective_done`, `get_count`, `track(quest)`. A quest whose every objective is met completes, pays its rewards into the inventory and emits `quest_completed`; the tracked quest (the latest started, or whatever `track` picked) shows on the `QuestTracker` (`scenes/quest_tracker.tscn`, a layer of its own under the Player, top right, so it is drawn whether or not the on-screen controls are) with its objectives ticked as they go. It saves with the Player.
- **`QuestScreen`** (`scenes/quest_screen.tscn`): the Quests page from the pause menu (the `Quests` button, `Pause.quests_screen_scene`), every quest the log knows with its description and objectives, and Track for an active one.
- The demo has the lot: `resources/dialogues/demo_guide.tres` and `resources/quests/demo_errand.tres`, on the Guide in the courtyard.

### 13. Local Split Screen (`SplitScreen`, `PlayerView`)
- **`SplitScreen`** (`scenes/split_screen.tscn`, a `Control` over the whole window): give it a `player_scene` and a `player_count` (1 to 4) and it splits the window into that many `PlayerView`s (a `SubViewportContainer` whose SubViewport shares the parent's `World3D`), each with a Player of its own inside it, so the camera, the HUD, the menus and the audio listener of each belong to their own view. `layout` is `AUTO` (two stack top and bottom, more make a grid), `HORIZONTAL`, `VERTICAL` or `GRID`; `spawn_points` places them.
- **One pad per player, nothing renamed.** Player one is the first pad, player two the second (`Player.input_device`). A `PlayerView` forwards only its pad's events to its SubViewport (`_propagate_input_event`), the Player's polled reads ask that pad (section 5), and the InputMap is the ordinary one. The keyboard and the mouse drive nobody in a split screen: two people cannot share them, so co-op is pads only. A device-less `InputEventAction` (a test, a script) reaches every view.
- It is for players on one machine, not for a networked session: put it under a world instead of a `PlayerSpawner`. `scenes/demo/split_screen_demo.tscn` is the demo arena for two.

### 14. Gameplay Style Demos (`DemoScene`, `DemoAutopilot`, `WantedLevel`, `MuzzleFlash`, `TreasureChest`)
The hub (`scenes/demo/demo.tscn`) has a **Gameplay Styles** panel; each button opens a self-contained scene under `scenes/demo/<style>/` that plays one style properly, not as a diorama: its own equipment to find, things to pick up, enemies to fight, an errand, a checkpoint, a kill zone and a `SaveGame`. Each has a GUT test (`tests/test_<style>_demo.gd`) and a recording made by its autopilot (below). The HUD is on in every demo, the whole set of buttons with the contextual words swapping in as you go: "Pick Up" beside a coin, "Open" at a chest, "Climb" at a wall, "Aim" on the trigger with a gun in hand.
- **Zelda** (`zelda_demo.tscn`, Breath of the Wild controls, lock-on Focus, stamina and the paraglider on): a village with an elder whose errand (`resources/quests/zelda_camp.tres`) counts the raiders' camp and the shrine chest, a `BronzeSword` on the stand, a `WoodenShield` in a crate and a `HuntersBow` on a barrel with arrows in the pouch, coins in the grass, three `CampRaider`s, a `TreasureChest` of coins, a pond to swim, a cliff to climb and glide off.
- **GTA** (`gta_demo.tscn`, Grand Theft Auto layout: A Sprint, B Attack, X Jump, Y Action; Focus aims freely over the shoulder): a downtown intersection built from Quaternius' Downtown City kit, a `Pistol` on the sidewalk with clips in an ammo box, a fixer with a job (`resources/quests/gta_alley.tres`), a gang of `GangGunman`s in the lot across the street, their stash with a `Rifle`, magazines, a health pack (used the moment it is taken) and the data card, and the wanted stars: the shooting brings `PatrolCop`s running, and the stars fade once none has you in sight.
- **Souls** (`souls_demo.tscn`, lock-on Focus, stamina on, `enable_dodge` on, every swing at `attack_stamina_cost`): a bonfire to rest at, a sword and shield beside it, a corridor of `Hollow`s in the ruins, a `BronzeGreatsword` on an altar, a fog gate and the `Gravelord` boss with its bar. The souls the dead leave (`resources/items/souls.tres`) drop as a pickup where you fall and a second death moves them; coming back to the fire refills the flasks and stands the hollows up again.
- **Platformer** (`platformer_demo.tscn`, the `PLATFORMER` layout: A Jump, B Sprint, X Attack, Y Action; `enable_double_jump` on): islands in the sky with coins taken on touch (`ItemPickup.auto_take`), a `MovingPlatform`, a `BouncePad` mushroom, `PlatformGoon`s with a `Stompable` head, checkpoints along the way, the sea under it all as the kill zone, and a flag; the Skyline quest counts the coins and the flag.
- **FPS** (`fps_demo.tscn`, the camera in the head from the start): a base on lockdown built from CSG rooms and Quaternius Sci-Fi props, a `Pistol` off a desk with clips beside it, `Sentry` riflemen in the corridor and the control room, a security card (`resources/items/security_card.tres`) that a `LockedDoor` needs, a `Rifle` in the armoury, the alarm that brings a `WaveSpawner`'s wave, health packs on touch, and the lift out; the Breakout quest counts the card, the door and the lift. The sentries path through the rooms on a navigation mesh the scene bakes from the base's colliders when it loads.
- **TPS** (`tps_demo.tscn`, the GTA layout's free aim over the shoulder): a floodlit compound at night, a `Rifle`, a `Pistol` and their magazines at the gate, sandbags and crates to crouch behind, three waves from a `WaveSpawner` over the breached wall that start when the sandbags are reached, ammo caches and health packs between them, and a `LockedDoor` gate kept `sealed` by the script until the last wave is down, with the extraction pad past it; the Holdout quest counts the waves and the pad.
- **Stealth** (`stealth_demo.tscn`, lock-on layout, stamina off): a manor's grounds at dusk with three `Guard`s walking `patrol_points` routes, each with a `VisionCone` drawn on the ground that fills from clear to yellow to red; crouching halves how far they see, the Stealth ability hides you outright, a strike on a guard who is not hunting you is a takedown (`EnemyNpc.sneak_attack_multiplier`), a filled cone sets the guard and everyone in the `Guards` group on you, and four seconds out of sight they give up and walk back (`EnemyNpc.lose_target`). The sealed orders in the pavilion and the far gate are the run.
- **Horror** (`horror_demo.tscn`, lock-on layout, stamina off): a black cellar of CSG rooms and Fantasy Props dressing, a `Flashlight` under the camera mount on the d-pad's bottom button (`PlayerControls.bind_slot`), torn pages to read (`Readable`), batteries that go straight into the torch, the `Stalker` (an `EnemyNpc` in the `Stalkers` group) that only moves while the beam is off it, the cellar key on the far crates and a `LockedDoor` at the top of the stairs; the Cellar quest counts the key and the way out. A battery bar sits under the HUD's top centre.
- **`Flashlight`** (`scripts/flashlight.gd`, a SpotLight3D): `action` toggles it, `battery` (seconds) drains while on and `capacity` caps it, `went_dark` fires when it runs out, `lights(target)` says whether a target stands in the beam with nothing between, and every `EnemyNpc` in `freezes_group` that does stands still (`movement_scale` 0) until the beam leaves it. `Readable` (`scenes/readable.tscn`) is a walk-up note: Action opens its `dialogue` on the Player's dialogue screen with `title` as the speaker. `PlayerControls.bind_slot(slot, action, label)` moves one HUD slot to another action live, the way a scheme moves the four face buttons.
- **Survival** (`survival_demo.tscn`, lock-on layout, stamina off): an island with a beach to comb for branches and loose stones, a `CraftingStation` workbench with three `Recipe`s, a `StoneAxe` (`can_log`) that fells `TimberTree`s, a `StonePickaxe` (`can_mine`) that breaks `Boulder`s, `BerryBush`es that give to bare hands, a `WaterSource` stream, and a `Vitals` node on the Player whose hunger and thirst drain and hurt at empty; the Shelter quest is the three recipes, and the last one raises a roof by the camp. Hunger and thirst bars sit under the HUD's top centre.
- **`Vitals`** (`scripts/vitals.gd`, a Node on the Player): `hunger` and `thirst` drain at `hunger_drain` and `thirst_drain` a second and, at zero, take `starving_damage` a second off the `Health`; `eat` and `drink` fill them, `vitals_changed`, `starving`, `dehydrated` and `recovered` say so.
- **`Gatherable`** (`scripts/gatherable.gd`, a StaticBody3D in the "Gatherable" group): a tree, a boulder, a bush. A swing that reaches it (`HitDetection.strike_groups` now covers Gatherable as well as Focusable) counts when the tool `needs` what it needs (`LOGGING` wants `Equipment.can_log`, `MINING` wants `can_mine`, `NOTHING` takes bare hands); every `hits_per_yield` hits put `yield_count` of `item` in the striker's bag, and after `total_yields` it is spent, back after `regrow_seconds` if set.
- **`Recipe`** (`scripts/recipe.gd`, a Resource): `ingredients` out of the bag, `result` in, or on the skeleton when the result is equipment with an `equipment_scene`. **`CraftingStation`** (`scenes/crafting_station.tscn`): walk up, Action opens the **`CraftingScreen`** (`scenes/crafting_screen.tscn`, a `PlayerMenuLayer`) listing its `recipes` with their costs, greyed while the bag cannot pay; `craft(player, recipe)` is the making, `crafted` the signal. **`WaterSource`** (`scenes/water_source.tscn`): stand in it, Action drinks `drink_amount` onto the Player's `Vitals`.
- **Action RPG** (`arpg_demo.tscn`, lock-on layout with the camera held from above by `Camera.locked_view`): a crypt of halls, a sword and shield at the door, click-to-move with the mouse (the Player's own navigation, cursor shown) or the stick on a pad, a `Fireball` `DamageAbility` on the shoulder button with an energy pool to pay for it, three waves of `Ghoul`s from a `WaveSpawner` that drop gold and potions where they fall (`ItemPickup.auto_take`), and the Crypt Lord on his sigil; the Crypt quest counts the halls and the lord and pays two hundred coins.
- **`Camera.locked_view`** holds the third-person camera at `locked_pitch_degrees` and `locked_yaw_degrees`, `locked_distance` out, and ignores the look stick and the mouse. **`DamageAbility`** (`scripts/damage_ability.gd`) is an `Ability` that hurts its target through `take_hit` for `damage`, with `splash_radius` for the Focusable bodies around the impact; with a `projectile_speed` it flies there as a bolt, and its `elements` apply on impact as for any ability. Past the hit it can keep hurting (`over_time_damage` spread over `over_time_duration` in one-second ticks, a burn) and it can slow what it lands on (`slow_factor` for `slow_duration`, through the target's own `slow()`, a frostbolt), both on the splashed bodies as well; `get_details()` reads whichever of those the ability actually has out to the spells screen.
- **Flight** (`flight_demo.tscn`, `enable_flying` on): the skyline from the GTA demo's kit seen from a rooftop pad, a `RingCourse` of eight rings that light up one at a time and time the run, and a tower to set down on at the far end; jump, then jump again in the air to take off, the stick flies, Jump climbs, Action dives, and a double tap of Action lands. The Ring Run quest counts the rings in order and the landing.
- **`RingCourse`** (`scripts/ring_course.gd`): its child Area3D rings (`scenes/flight_ring.tscn`) are passed in order, the next one lit `next_color`, the passed ones `lit_color`, the rest `dim_color`; `ring_passed` and `course_finished(seconds)` are the signals, `restart` resets it.
- **`VisionCone`** (`scripts/vision_cone.gd`, a Node3D under an `EnemyNpc`): `range_metres`, `angle_degrees` and `eye_height` describe what the guard sees, with a line-of-sight ray; `suspicion` fills over `detect_seconds` on a Player in view and drains over `lose_seconds` out of it, `spotted` and `lost` fire, `alert_group` names who else joins the hunt, and `show_cone` draws it. Enemies also gained `patrol_points` (walked in a loop at `patrol_speed`, pausing `patrol_wait` at each) and `sneak_attack_multiplier`.
- **`LockedDoor`** (`scenes/locked_door.tscn`, `scripts/locked_door.gd`): walk up and the Action button reads `Open`, or `locked_label` without `key` in the bag; Action slides or turns `panel` open (`open_offset`, `open_degrees`, `open_seconds`), drops the collision, `consumes_key` if asked, and emits `opened`; `refused` fires on a press without the key. `sealed` shuts it by script instead (a gate until the waves are done), whatever the bag holds. `stays_open` off closes it again once the Player walks away.
- **`WaveSpawner`** (`scripts/wave_spawner.gd`): `start()` brings `waves[0]` enemies (`enemy_scenes`, cycled) in at `spawn_points`' children and sets them on the Player; when the last of a wave is down the next comes after `between_waves` seconds, and `all_cleared` fires after the last (`wave_started`, `wave_cleared`, `enemy_spawned` along the way).
- **Double jump and bounces** (`Player.enable_double_jump`, `air_jumps`, `air_jump()`, `bounce(speed)`): a Jump press in the air jumps again `air_jumps` times before the feet touch ground, on the jump clip; `bounce` throws the Player straight up at a speed, which is what a `BouncePad` (`scenes/bounce_pad.tscn`, an Area3D) and a `Stompable` (an Area3D on an enemy's head: a Player coming down onto it deals `damage` and is bounced) use. `MovingPlatform` (`scenes/moving_platform.tscn`, an AnimatableBody3D) slides between its start and `travel` over `seconds`, pausing at the ends, and carries whoever stands on it.
- **Swings that reach** (`HitDetection.strike_reach`): partway into every swing, any Focusable body within `strike_reach` in the front arc is struck once, so a hit lands on what plainly stands in range rather than only where the thin blade shape happens to pass; props still need the blade itself.
- **Dodge roll** (`scripts/dodging.gd`, `Player.enable_dodge`): a tap of Sprint (`dodge_tap_seconds`) rolls on the FowardFlip clip along the direction moved, or backsteps on Backflip when still, for `dodge_stamina_cost`; the roll's first `dodge_iframe_seconds` take no hit (`Player.dodge_invulnerable`, honoured by `take_hit`). Holding Sprint still sprints. `Stamina.spend(amount)` is what a swing or a roll pays with, and `attack_stamina_cost` puts a price on every swing of a combo (0 keeps them free).
- **`Bonfire`** (`scenes/bonfire.tscn`, `scripts/bonfire.gd`): the Souls checkpoint. Walk up, the Action button reads Rest; `rest(player)` takes its `Checkpoint` (`Checkpoint.take`, the same as walking through one, so a `SaveGame` saves), heals, tops `flask` up to `flasks` and puts every dead `EnemyNpc` under `revives` back at its post (`EnemyNpc.revive(true)`); `rested(player)` is for the scene.
- **`WantedLevel`** (`scenes/wanted_level.tscn`, `scripts/wanted_level.gd`): the GTA meter. `raise(by)` lights stars (to `max_stars`) and spawns one `officer_scene` per new star at the nearest `spawn_points` child at least `min_spawn_distance` away, set on the Player; hurting an officer restarts the fade and killing one is another star; a star fades every `decay_seconds` once no officer still standing has the Player in sight (`is_chased`), and at no stars the rest stand down. Give it a `stars_container` of `TextureRect`s for the HUD; `watch(officer)` puts an officer placed in the scene under the same rules.
- **`MuzzleFlash`** (`scenes/muzzle_flash.tscn`): a flash and a light for any `Firearm` or shooting `EnemyNpc`; sit it under the Muzzle marker and wire `fired` to `flash`. The pistol and rifle scenes under `scenes/demo/gta/` show a full `Firearm` (muzzle, fire timer, laser sight, flash, pickup area) and the `AmmoItem`s (`pistol_clip.tres`, `rifle_magazine.tres`) that reload them from the inventory.
- **`TreasureChest`** (`scenes/treasure_chest.tscn`): a walk-up chest that offers "Open" on the Action button, plays its lid and hands its `items` to whoever opened it; `opened(player)` is the signal a quest counts.
- **`DemoScene`** (`scripts/demo_scene.gd`) is what the demos extend: it sets the Player's `control_scheme`, forces the HUD on (`Player.hud_mode_override`), calls `setup_player` for the style's gear, bakes a scene's `NavigationRegion3D` from its CSG and static boxes a few frames in (`bake_navigation`), and when the game was started with `--autopilot` builds and runs a **`DemoAutopilot`** (`scripts/demo_autopilot.gd`): a fluent, physics-frame-paced script of `walk`, `walk_to`, `hop`, `fly_to`, `look`, `watch`, `watch_until`, `hold`, `press`/`release`, `tap`, `click` (a mouse click where the camera shows a point), `aim` (camera on a target, trigger held or tapped, only within range), `melee` (lock-on swings with rolls between), `wait`, `wait_until`, `call_step` and `warp` steps, plus `talk` on the scene for a paced conversation. `tools/record_demo.sh <scene> <seconds> <out>` films it with Godot's movie writer into an mp4 and a contact sheet, and the run quits itself when the sequence ends; `tools/model_shot.gd` renders a model with an axis gizmo to see which way it faces before it goes into a scene.

## Installation

### Option 1: Manual Installation (Recommended)

1. Download or clone this repository.
2. Copy the `addons/3d_player_controller/` directory into your Godot project's `addons/` folder:
   ```text
   your_godot_project/
   ├── addons/
   │   └── 3d_player_controller/
   │       ├── assets/
   │       ├── plugin.cfg
   │       ├── plugin.gd
   │       ├── scenes/
   │       │   ├── player.tscn
   │       │   ├── player_controls.tscn
   │       │   └── ...
   │       ├── scripts/
   │       └── tests/
   ├── project.godot
   └── ...
   ```
3. Add the [Controls addon](https://github.com/kirbycope/godot-controls) at `addons/controls/`, which this addon
   requires: `player.tscn` instances its HUD, and the world prompt your props use comes from it. As a submodule:

   ```powershell
   git submodule add https://github.com/kirbycope/godot-controls.git addons/controls
   ```

   The folder has to be `addons/controls` whatever you call the checkout, because the scenes reference it by path.
4. Open your project in **Godot 4.8+**.
5. Go to **Project > Project Settings > Plugins** and toggle the **Enable** checkbox next to **3D Player Controller**.

The addon needs no `project.godot` edits. The Steam lobby UI and the `Loading` screen are inside `addons/3d_player_controller/scenes/` and work without GodotSteam installed. The inventory comes with the addon, at `addons/3d_player_controller/inventory/`: the Player's `Inventory` node is its scene.

### Option 2: Download Release Zip

1. Download `3d_player_controller-vX.Y.Z.zip` from the [Releases](https://github.com/kirbycope/godot-3d-player-controller-v3/releases) page.
2. Extract the `3d_player_controller` folder directly into your project's `addons/` directory.

---

## Interactive Demo Scene

Open and run **`res://addons/3d_player_controller/scenes/demo/demo.tscn`** to explore the entire locomotion, combat, and interaction sandbox:
- **Playground Arena**: Features a courtyard, climbable walls, slopes/ramps, high towers for paragliding, and a water pool for swimming.
- **Quick Teleports**: Instantly jump to the Glider Tower, Water Pool, Climbing Wall, or Main Courtyard.
- **Full Debug HUD**: Press `F3` at any time to open the complete debug telemetry and feature toggles panel (state, speed, stamina, perspective, flight, ragdoll, etc.).
- **The Guide**: a `TalkingNpc` in the courtyard with an errand (`resources/quests/demo_errand.tres`): accept it in the dialogue, swim in the pool, come back for the apples. The quest tracker sits top right, the Quests page is in the pause menu.
- **Checkpoint, kill zone and saving**: the beacon by the courtyard is a `Checkpoint`; fall off the arena and the `KillZone` under it kills you back to it, with the death screen in between. The pause menu's Save Game and Load Game write and read `user://savegame.tres` through the scene's `SaveGame`.
- **Gameplay Styles**: the panel's second row opens the style demos of section 14 (Zelda, GTA, Souls, Platformer, FPS, TPS, Stealth, Horror, Survival, Action RPG, Flight), each a small game of its own that comes back here.

---

## Playing the demo

The demo runs in a browser at <https://timothycope.com/godot-3d-player-controller-addon/>. A GitHub Action exports it on every
push to `main` and hands it straight to Pages, so the export itself is never committed: the projects that use this
addon fetch it with a script, and a web export is tens of megabytes that git cannot compress.

This repository **is** that project. It follows the layout the
[Godot Asset Library](https://docs.godotengine.org/en/stable/community/asset_library/submitting_to_assetlib.html)
expects, with the addon at `addons/3d_player_controller/` and a `project.godot` at the root, so you can
clone it, open it in Godot and edit the addon in place. Nothing is copied anywhere first.

```
project.godot                    the demo project, which is this repository
addons/3d_player_controller/     the addon, plugin.cfg and all
addons/controls/                 what the addon needs, a submodule
addons/gut/                      the test runner
```

Installing from the Asset Library takes `addons/` and leaves the rest; Godot flags the root
`project.godot` as a conflict and skips it, which is why it can live here harmlessly.

There used to be a second Godot project under `demo/`, filled with a `robocopy` mirror of this
repository. It is gone. It made the addon effectively uneditable: the only project that mounted the
addon held a throwaway copy of it, so edits to a scene there, the AnimationPlayer especially, were
destroyed by the next mirror.

---

## Quick Start

### 1. Instantiate the Player Scene

Drag and drop the ready-to-use Player scene into your level:

```text
res://addons/3d_player_controller/scenes/player.tscn
```

### 2. Scene Setup Requirements

| Node | Where it goes | Set in the Inspector |
|---|---|---|
| `Player` (instance `scenes/player.tscn`) | A child of your level root, standing above the floor | `enable_flying`, `enable_paraglider`, `enable_ragdoll`, `enable_stamina`; `paraglider_scene` for the optional glider (the addon ships `scenes/paraglider.tscn`; the Controls addon's `action_prompt.tscn` is the interaction prompt your props can use); `mass` and `push_force` for shoving rigid bodies |
| Floors and walls | `StaticBody3D` + `CollisionShape3D`, or CSG with `use_collision = true` | Put them in the `GRASS`, `DIRT`, `STONE` or `WOOD` group to pick the footstep sounds |
| `NavigationRegion3D` | Wrapped around the walkable floor and baked | Needed for the player's `NavigationAgent3D` (auto-walk and teleports) |
| Water | An `Area3D` in the `WATER` group with a `CollisionShape3D` | Connect `body_entered` / `body_exited` to a script that calls `player.enter_water(area)` / `player.exit_water(area)` |
| Lighting and camera | Your own `WorldEnvironment` and `DirectionalLight3D` | The Player scene brings its own `Camera3D` on a `SpringArm3D`, so add no camera |

Minimum scene:

```text
Level (Node3D)
├── WorldEnvironment
├── DirectionalLight3D
├── NavigationRegion3D
│   └── Ground (StaticBody3D, group GRASS)
└── Player (player.tscn)
```

The player's HUD (`Controls`, `Debug`, `Pause`, `Settings`, `Inventory`, `Stamina`, `Crosshair`) lives inside `player.tscn`, so nothing else is needed on screen.

### How `demo.tscn` does it

| Demo node | What it demonstrates |
|---|---|
| `Player` | `player.tscn` instanced with `paraglider_scene` (`scenes/paraglider.tscn`) set in the Inspector; `demo.gd` switches on `enable_paraglider` and `enable_stamina` in `_ready()`. |
| `NavigationRegion3D/Ground` (group `GRASS`) | The baked floor the `NavigationAgent3D` walks on, with grass footsteps. |
| `Structures/Tower`, `ClimbingWall` (group `STONE`), `Ramp` (group `WOOD`) | Climbing, hanging, sliding and a high launch for the paraglider, with stone and wood footsteps. |
| `Structures/PoolBasin/WaterPool` (`Area3D`, group `WATER`) | `body_entered` / `body_exited` are connected in the scene to `_on_water_pool_body_entered` / `_on_water_pool_body_exited`, which call `enter_water(water_pool)` / `exit_water(water_pool)` for swimming and diving. |
| `Markers/Courtyard`, `Tower`, `Pool`, `ClimbingWall` + `HUD/TeleportPanel` buttons | Each button's `pressed` is connected in the scene to `_on_teleport_pressed` with the marker's NodePath bound, and the handler moves the player there. |

### 3. Default Keybindings

| Action | Keyboard / Mouse | Gamepad (Xbox) |
|---|---|---|
| **Move** | `W` / `A` / `S` / `D` | Left Stick |
| **Look / Aim** | Mouse Motion | Right Stick |
| **Jump / Fly Up / Hop** | `Space` | `A` (Button 0) |
| **Sprint / Fast Swim** | `Shift` | `B` (Button 1) |
| **Crouch / Slide / Drop** | `Ctrl` | `X` (Button 2) / `Right Stick Click` |
| **Attack / Shoot** | `Left Click` | `Right Trigger` |
| **Aim Bow / Focus** | `Right Click` | `Left Trigger` |
| **Pick Up / Throw Object** | `E` / `Left Click` | `Right Bumper` / `Right Trigger` |
| **Cast Ability / Ability Wheel** | `Q` (Tap / Hold) | `Left Bumper` (Tap / Hold) |
| **Radial Menu / Prev Weapon** | `J` (Hold) | `D-Pad Left` (Hold) |
| **Radial Menu / Next Weapon** | `L` (Hold) | `D-Pad Right` (Hold) |
| **Toggle Perspective** | `F5` | `View / Back` |
| **Debug HUD** | `F3` | — |
| **Toon shading** (cycle Off, Newspaper, Cel, Binbun, BotW) | `F6` | — |
| **Chat** | `Enter` | — |
| **Pause Menu** | `Escape` | `Start` |
| **Dismount** (`whistle`, a rideable's exit) | `K` | `D-Pad Down` |
| **Push-to-talk** (`broadcast`, voice chat) | `V` (Hold) | none |
| **Reload** (`reload`, the equipped firearm) | `R` | none (an empty magazine reloads on the trigger) |
| **Flashlight** (`flashlight`, a [Flashlight]) | `F` | none, unless a scene puts it on a slot (`PlayerControls.bind_slot`) |

All of the above are registered at runtime when missing from the project's InputMap: the pad button from the slot it is drawn on, everything else from `PlayerControls.PLAYER_ACTIONS`.

---

## Adding New Mixamo Animations

To prepare and import custom Mixamo animations with Root Motion:

1. Log into [Mixamo](https://www.mixamo.com/) and select the **Y Bot** character.
2. Search for and download your desired animation:
   - Format: **FBX Binary (.fbx)**
   - Skin: **Without Skin**
   - Frames per Second: **30** or **60**
3. Move the downloaded `.fbx` into `addons/3d_player_controller/assets/mixamo/animations/source/`
   **in this repository**. The
   animations belong to the addon, so they are added here and picked up by a game when it next
   takes this repository. A consuming project's `addons/` copy is a copy: work added there is
   overwritten the next time it updates.
4. Process root motion with the Blender script, from the root of this repository:
   ```bash
   blender --background --python tools/bake_root_motion.py
   ```
   It reads `addons/3d_player_controller/assets/mixamo/animations/source/` and writes `.glb` files
   to `addons/3d_player_controller/assets/mixamo/animations/root_motion/`, adding a `root` bone and reparenting `hips` to it so the
   positional data moves from `hips` to `root`. Pass `--source` and `--dest` to override either.
   `tools/add_root_to_character.py` does the same for the character mesh itself
   (`addons/3d_player_controller/assets/mixamo/characters/y_bot.fbx`).
5. In Godot, reimport the resulting `.glb` as an **Animation Library** retargeted to
   `mixamo_root_bone_map.tres`, and set Loop Mode to Linear for cycles (not for one-shots such as
   emotes).
6. Open `addons/3d_player_controller/scenes/player.tscn` in this project, select `AnimationPlayer`,
   and load the animation into the library, then wire the AnimationTree. The addon is mounted at
   `res://addons/3d_player_controller/` here, so this is the real file, not a copy.
7. Commit and push here, then update each consuming project. `godot-3d-player-controller-v3`
   vendors this addon and takes new work with `python tools/pull_addons.py 3d_player_controller`;
   the projects that still consume it as a git submodule bump their pointer instead.

### Every animation lives in `tuned/`, outside the import pipeline

An animation imported with **Save to File** leaves a `.tres` beside its `.glb` that looks like
generated output. Some of it was not. The `%GeneralSkeleton:Hips` position track in each swim
animation is offset by hand so the body sits at the waterline, `Driving`'s two `LowerLeg` rotation
curves were collapsed to straighten the leg so the foot stopped poking through the floor of the CRV,
`Entering Car`'s seat dip was lowered, seventeen jump clips carry their lift on `Hips`, and fourteen
clips carry an `execute_jump` method track that exists in no `.glb` at all. Re-importing gives back
the raw Mixamo capture and drops every one of those edits.

| Animation | Hips height | Raw capture | Offset |
| --- | --- | --- | --- |
| `Swimming` | 1.0995283 | 0.69952834 | +0.4 |
| `Swimming At Edge` | 1.2018158 | 1.4994758 | -0.29766 Y, -0.1 Z |
| `Swimming To Edge` | 1.1010405 | 1.4610405 | -0.36 |

That work was lost twice before anyone traced it, and the way it is lost is worth stating plainly,
because the obvious experiment gives the wrong answer. Re-importing a small project holding only the
`.glb`, its `.import` and the `.tres` leaves the file alone, even with a cold `.godot` cache, after
the asset has moved, with a stale `uid` and with `importer_version` bumped. **Cloning this
repository fresh and letting Godot import it wipes them on the first pass.** Scale and context
matter, so test a fresh clone, not a reduction of one.

Godot offers no setting that saves an imported track. `keep_custom_tracks` does not, on its own or
with the track marked `imported = false`; an `import_script` runs with the right offsets but too
late, after the resource has been written.

So no animation is importer output any more. All 29 saved animations are hand-owned
`AnimationLibrary` resources in
[`assets/mixamo/animations/tuned/`](assets/mixamo/animations/tuned), each holding one animation still
named `mixamo_com` so `"Swimming/mixamo_com"` resolves unchanged. Four things hold the line together:

- **No `.tres` sits beside a `.glb`.** `root_motion/` holds sources and import settings only.
- **No `.glb` has `save_to_file` enabled.** That setting is the only thing that makes Godot write an
  animation resource, so with it off across all 202 imports the importer writes none.
- **`keep_custom_tracks` is `true` for all 29**, so if `save_to_file` is ever turned back on, the
  method tracks calling `execute_jump` survive even though an imported track would not. The other
  173 imports write nothing and have nothing to keep, so they are left as they are.
- **Every track in `tuned/` is marked `imported = false`**, 1589 of them, because none of it is the
  importer's to claim any more.

Verified on a fresh clone: a cold import of 1640 files changed nothing under `tuned/` and recreated
no `.tres`.

Tune another animation the same way rather than editing beside its `.glb`: save the library into
`tuned/`, repoint `player.tscn`, turn its `save_to_file` off, mark its tracks `imported = false`, and
add it to `tests/test_swim_animation_heights.gd`. That test holds the Hips height and total key count
of all 29, fails if any comes back raw, and fails if a `.tres` reappears beside a `.glb` or a
`save_to_file` is switched on. Judge a diff by magnitude rather than by its existence: the
restructure that reverted the swim heights also rewrote 16 other animations, every one a rotation
difference of about 1e-7 from a re-export with no position change at all.

---

## Example resources

`addons/3d_player_controller/resources/` holds the resources the addon needs to run alone: two abilities, three accuracy profiles and three replication configs. They reference only this addon (its scripts, icons and TomMusic sounds), never a host project's `res://resources/...` or `res://scenes/...`, so the addon works by itself, and the [inventory's](inventory/README.md#example-resources) demo tree is built from the two abilities. A game's own spells, fish and items live in its project-level `resources/` (see the [project README](../../README.md#example-resources)).

| File | Class | What it is | Used by | Tests that load it |
|---|---|---|---|---|
| `resources/abilities/stealth.tres` | `StealthAbility` (`scripts/stealth_ability.gd`) | Instant toggle, sets `Player.is_stealthed` | `scenes/player.tscn` (`Abilities.abilities`), the inventory's `spell_tree_demo.tres`, the host's `world_player.tscn` and QA tree | `tests/test_abilities.gd`, the inventory's `test_spellbook.gd`, `test_spells_screen.gd`, `test_spell_tree_editor.gd` |
| `resources/abilities/heal.tres` | `HealAbility` (`scripts/heal_ability.gd`) | 1.5 s cast, restores `amount` health | `player.tscn`, the inventory's demo tree, the host's `enemy_spellcaster.tscn` | The same |
| `resources/accuracy/pistol.tres`, `rifle.tres`, `bow.tres` | `Accuracy` (`scripts/accuracy.gd`) | Spread cones per weapon (`spread_degrees`, `expert_spread_degrees`, `expert_level`) | Nothing in the addon's own scenes; the host's weapons in `world.tscn` and its `enemy_archer.tscn` and `enemy_rifleman.tscn` take them in the `accuracy` export | `tests/test_accuracy.gd` |
| `resources/boss_replication.tres`, `character_body_replication.tres`, `rigid_body_replication.tres`, `enemy_replication.tres` | `SceneReplicationConfig` | Multiplayer property lists for a boss, a character body, a rigid body and an enemy's state | `scenes/boss.tscn`, `scenes/enemy_npc.tscn`, `scenes/talking_npc.tscn`; the host's NPCs and props | None directly |
| `resources/quests/demo_errand.tres` | `Quest` (`scripts/quest.gd`) | The Guide's errand: talk, swim, two apples | `resources/dialogues/demo_guide.tres`, `scenes/demo/demo.gd` | `tests/test_quests.gd`, `tests/test_dialogue.gd` |
| `resources/dialogues/demo_guide.tres` | `Dialogue` (`scripts/dialogue.gd`) | The Guide's conversation before, during and after the errand | `scenes/demo/demo.tscn` (the Guide) | `tests/test_dialogue.gd` |

Adding more here:

- An ability: New Resource, `HealAbility` or `StealthAbility`, or a new script under `scripts/` that extends `Ability` (override `activate`, `impact`, and `deactivate` for toggles). Save it under `resources/abilities/` with an icon from `assets/game_icons/` or `assets/icons/` and sounds from `assets/tommusic/`. List it in the Player's `Abilities.abilities` to put it on the wheel, or on a `SpellTree`; the Spell Tree panel's palette finds it on its own.
- An accuracy profile: New Resource, `Accuracy`, saved under `resources/accuracy/`, assigned to the weapon's `accuracy` export.
- A quest: New Resource, `Quest`, its objectives as `QuestObjective` sub-resources, saved under `resources/quests/`; start it from a dialogue line or choice, or from code with `player.quest_log.start()`.
- A dialogue: New Resource, `Dialogue`, its lines as `DialogueLine` sub-resources (and their `DialogueChoice`s), saved under `resources/dialogues/`, set on a `TalkingNpc`.
- `test_abilities.gd` and `test_accuracy.gd` preload these files by name, so renaming one means updating them.

---

## Testing

The controller carries its own test suite, powered by [GUT (Godot Unit Test)](https://github.com/bitwes/Gut)
9.7.1, vendored at `addons/gut/`. The tests belong to this repository and run here, not from a game
that consumes the addon: this project imports a fraction of a full game's assets, so a run answers in
seconds rather than minutes.

The Controls addon is a submodule, so clone with `--recurse-submodules` or run
`git submodule update --init --recursive`; otherwise `addons/controls` is empty and nothing loads.

### Running the tests headless

```powershell
& 'C:\Godot\godot.exe' --headless --audio-driver Dummy --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```

Add `-gtest=res://addons/3d_player_controller/tests/test_chat.gd` to run a single file.

### Running the tests in the editor

1. Open `project.godot` at the root of this repository.
2. Open the **GUT** panel at the bottom of the editor.
3. The three directories above are already listed in `.gutconfig.json`, so click **Run All**.

CI runs the same three directories on every push and pull request to `main`, in
`.github/workflows/gut-tests.yml`. It installs Godot 4.8-dev4 directly rather than using the
`barichello/godot-ci:4.7` container the other addons here test in, because scenes saved by a 4.8 build
carry a `unique_id` that 4.7 cannot parse.

### The editor plugin's own guard

`tests/test_editor_plugin.gd` covers `plugin.gd`, which every other check here misses: no test
instantiates an `EditorPlugin`, and this project does not enable its own plugin, so a plugin that has
stopped compiling stays green all the way to the project that installs the addon and finds it will not
enable. Loading a GDScript compiles it and a preload of a missing file is a compile error, so
`load()` on it comes back null when it is broken. The other two tests name the preload that does not
resolve, and check that every custom type put in the Create New Node dialog on the way in is taken off
again on the way out, so disabling the plugin leaves no entry pointing at nothing.

---

## Assets

Textures here are committed at the resolution they shipped with, compressed losslessly with Pillow
and never downscaled (`python tools/tinyify.py addons/3d_player_controller/assets`), so a desktop
build gets the fidelity the artist made. The 512 pixel cap belongs to the web build alone, where load time is the
constraint: a size limit is an import-time setting baked into `.godot/imported` rather than
something an export can choose, so `tools/web_texture_cap.py` applies it in the Pages workflow just
before the import pass, on a CI checkout that is thrown away. The `.import` files in this
repository carry no limit.

They are also imported **Lossless**, with `detect_3d/compress_to` on so the editor promotes a
texture to VRAM Compressed the first time it sees it used in 3D. That is Godot's own default. The
addon used to force `compress/mode=1` (Lossy) with promotion disabled, which re-encoded every image
through WebP at quality 0.7 before Godot ever saw it, wrecked normal maps and ORM masks, and still
uploaded uncompressed to VRAM, so it cost quality and saved nothing at run time; it existed only to
squeeze a committed `.pck` under GitHub's 100 MB limit, and nothing built is committed now.
`python tools/texture_import_policy.py` puts a repository back on that policy, `--check` reports
without writing, and `tests/test_texture_import_policy.gd` fails if anything drifts off it.

| Folder | Source | License |
|---|---|---|
| `assets/game_icons/` | [game-icons.net](https://game-icons.net/) (authors listed in the `.txt` file next to each icon, e.g. Lorc) | CC BY 3.0 |
| `assets/icons/` (`stealth.svg`, `heal.svg`) | Drawn for this addon | CC0 |
| `assets/kenney_nl/` (incl. `Lobby Icons/`, copied from Kenney's Game Icons pack; the Input Prompts icons moved to the [Controls addon](https://github.com/kirbycope/godot-controls)) | [Kenney](https://www.kenney.nl/) | CC0 |
| `assets/quaternius/` (characters, `paraglider/`) | [Quaternius](https://quaternius.com/) | CC0 1.0 |
| `assets/quaternius/fantasy_props/`, `stylized_nature/` (the models the Zelda and Souls demos use from the Fantasy Props MegaKit and the Stylized Nature MegaKit, with their textures) | [Quaternius](https://quaternius.com/) | CC0 1.0 (`License.txt` in each folder) |
| `assets/quaternius/sci_fi_essentials/` (the guns, ammo, health pack, key card, crate and barrel the GTA demo uses from the Sci-Fi Essentials Kit) | [Quaternius](https://quaternius.com/) | CC0 1.0 (`License.txt`) |
| `assets/quaternius/downtown_city/` (three buildings, the intersection and street tiles, bollard, planter, drain, manhole and AC unit from the Downtown City MegaKit; their `COLOR_0` vertex colours are stripped, Quaternius packs a mask there that Godot would multiply into the albedo) | [Quaternius](https://quaternius.com/) | CC0 1.0 (`License.txt`) |
| `assets/icons/` (`coin.svg`, `potion.svg`, `ammo.svg`, `cash.svg`, `medkit.svg`, `keycard.svg`, `star.svg`, `soul.svg`, `battery.svg`, `note.svg`, `wood.svg`, `stone.svg`, `berries.svg`, `shelter.svg`) | Drawn for this addon | CC0 |
| `assets/freesound/72853__benboncan__parachute.wav` | [Benboncan on Freesound](https://freesound.org/s/72853/) | CC BY 4.0 |
| `assets/freesound/570701__robinhood76__10136-flag-flicking-on-strong-wind-isolated.wav` | [Robinhood76 on Freesound](https://freesound.org/s/570701/) | CC BY-NC 4.0 (non-commercial) |
| `assets/tommusic/` | [TomMusic](https://tommusic.itch.io/) | Not stated (the pack's `ReadMe.txt` contains no license) |
| `assets/mixamo/` | [Adobe Mixamo](https://www.mixamo.com/) | Adobe Mixamo terms |
| `assets/pixabay/` (arrow swish and twang) | [djartmusic on Pixabay](https://pixabay.com) | Not recorded - fill in |
| `assets/shaders/botw_toon.gdshader` (the `BOTW` toon look, written for this addon after NekotoArts' [TRUE BoTW Toon Shader](https://godotshaders.com/shader/update-botw-toon-shader/), CC0) | This addon | MIT (the addon's) |
| `assets/shaders/binbun_stylized.gdshader` (the `BINBUN` toon look: a copy of the Ultimate Toon Shader's `stylized.gdshader`, so the addon stands alone) | [Binbun (Binbun3D)](https://binbun3d.itch.io/godot-ultimate-toon-shader) | Not recorded - fill in (itch.io pack, no license file) |
| `assets/le_lu/wind/` (the paraglider's wind streaks: two visual shaders, four textures, two meshes copied from the Wind VFX pack, so the addon stands alone without `weather_fx`) | [Le Lu](https://www.patreon.com/Le_Lu) | Not recorded - fill in (Patreon pack, no license file) |

---

## License

MIT License.
