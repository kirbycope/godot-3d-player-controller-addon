# 3D Player Controller for Godot 4.8+ 🎮

A feature-complete, modular 3D character controller built for **Godot 4.8+** using [CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html), [AnimationTree](https://docs.godotengine.org/en/stable/classes/class_animationtree.html), and Root Motion. Includes a full locomotion finite state machine, first- and third-person camera system, equipment and combat system, stamina mechanics, radial inventory, and contextual multi-platform input hints.

> [!NOTE]
> **Plugin Activation vs Scene Usage**:
> All core scripts use `class_name` (`Player`, `NodeStateMachine`, `Inventory`, `RadialMenu`, `Equipment`, `Camera`, `HeldObject`, etc.).
> - **Direct Usage**: You can instantiate `res://addons/3d_player_controller/scenes/player.tscn` directly into your scenes without enabling anything in Project Settings.
> - **Enabling the Plugin**: Enabling **3D Player Controller** in **Project Settings > Plugins** registers the addon and custom editor utilities.

---

## ✨ Features

### 1. Locomotion Finite State Machine (`NodeStateMachine`)
Organized state machine architecture separating primary lower-body locomotion states from upper-body actions:
- **Standing / Walking / Running**: Smooth acceleration, deceleration, and camera-relative motion.
- **Sprinting**: High-speed locomotion linked to stamina consumption.
- **Jumping & Falling**: Air control, coyote time, and smooth landing blending.
- **Crouching & Sliding**: Crouch walking and momentum-based sprinting slides.
- **Climbing**: Raycast-assisted wall detection, ledge hopping, and wall climbing. Walls become slippery during rain (BotW style): the climber periodically slides down, sprint climbing is blocked, and the climb animation slows (tunable via the `Rain Slipping` export group).
- **Hanging & Shimmy**: Braced and free-hang wall gripping with directional shimmy.
- **Swimming & Fast Swimming**: Water volume detection (`WATER` group), buoyancy, and surface swimming. Hard water entries spawn a one-shot droplet/foam splash (`water_splash.tscn`, tunable impact threshold). While swimming, the player feeds position/heading/speed to any swimmer-aware water shader (V-shaped wake when moving, ripple rings when treading — see WeatherFX `pond_water.gdshader`).
- **Diving**: Hold crouch while swimming to dive below the surface; hold jump to ascend and surface. The player model pitches around a hip pivot to follow the swim direction (camera stays level), gentle buoyancy floats you back to the surface when shallow, and stamina drains constantly underwater as a breath meter — exhaustion respawns you at the last safe shore. A fullscreen underwater filter (tint + wavy refraction + vignette) activates whenever the camera submerges. Contextual HUD controls swap between `Dive`/`Climb Out` and `Dive Deeper`/`Surface` automatically.
- **Paragliding**: Deployable glider with steering control and mid-air cancel. Thermal updrafts grant an immediate `+6 m/s` catch boost on entry (BotW standard) plus continued lift and stamina recovery; all glide/dive/updraft physics are exported tunables on the `Paragliding` state node.
- **Skateboarding**: Push acceleration, fast push, jumping, and dismounting.
- **Flying**: 3D spatial flying with vertical ascending/descending.
- **Sitting & Ragdoll**: Physical bone ragdoll simulation with get-up recovery.
- **Driving**: Seamless vehicle entry and exit integration.

**State node API** — `state.gd` (`NodeStateMachine`) is both the machine node and the base class of every state node under it:
- `start()` / `stop()` on the base enable/disable the state node and set/clear `player.current_state` (`States.NONE = -1` when no state is active). States extend them with `super.start()` / `super.stop()`; a node's `state` is derived from its name (`Standing` -> `States.STANDING`). `travel(from, to)` calls them directly.
- `action(keyboard, pad)` resolves a state's exported action pair for the current input type (`Controls.InputType.KEYBOARD_MOUSE` vs controller/touch).
- The base connects `Player.locomotion_node_changed` once; states override `_on_locomotion_node_changed(state_path)` (early-returning unless `process_mode == PROCESS_MODE_INHERIT`) to react to animation hand-offs (slide end, climb-on, hops, attacks) instead of polling the AnimationTree. Read `player.current_locomotion_node` / `player.current_locomotion_path` rather than the playback objects.
- `get_contextual_controls(input_type)` returns only state-specific labels; the base adds the shared `Perspective` / `Screenshot` / `Pause Menu` labels.
- Standing re-derives its grounded locomotion from `Inventory.equipment_changed` and `Player.exhausted_changed`; only the exhausted idle/moving swap (held analog input) is polled.
- Timers are `Timer` children created in `_ready` (physics-time): `Pushing.stop_grace_timer`, `Climbing.rain_slip_timer`, `Attacking.boxing_inactivity_timer`; Flying's double-tap uses a `SceneTreeTimer`.
- `Player.lethal_fall_speed` (15 m/s) is the shared ragdoll landing threshold for jumping and falling; `Player.wall_leap_horizontal_speed` / `wall_leap_vertical_speed` tune the climbing/hanging back-eject (`Player.leap_off_wall()`), and `Player.face_wall(delta)` / `clear_ledge_visuals()` are shared by the wall states.

### 2. First & Third Person Camera (`Camera`)
- Dynamic toggle between **First-Person** and **Third-Person** perspectives.
- SpringArm collision avoidance preventing clipping through geometry.
- Configurable mouse sensitivity, gamepad stick sensitivity, and axis inversion.
- Smooth rotation interpolation and camera smoothing.
- Interaction targeting: each physics frame the camera's `CameraRayCast` resolves the nearest ancestor of the hit collider that implements `display_menu(player)`, stores it in `looking_at`, and emits `looking_at_changed(previous, current)` only when it changes. The camera calls `hide_menu()` on the previous target and `display_menu(player)` on the new one, so any scene using the player gets prompts without extra code; pressing `action` calls `equip(player)` on targets that implement it.
- Input is handled in `_unhandled_input`, so UI controls consume clicks and scroll first.
- While driving or skateboarding, manual look input starts a `CAMERA_FOLLOW_DELAY` timer before the camera follows the player again.

### 3. Equipment, Combat & Interactions (`Equipment`, `HeldObject`)
- **Weapon Classes**: 1H Swords, 2H Greatswords (with tree-logging animation), Sword & Shield, Daggers, Axes, Staffs, and Rifles.
- **Bow & Arrow Mechanics**: Aiming, string draw, charge timing, arrow trajectory, and projectile firing.
- **Object Manipulation**: Pick up, carry, aim, rotate, and throw `RigidBody3D` objects or companion bodies. The throw charge bar is the `%ThrowChargeBar` node in `controls.tscn` (exported to `HeldObject.throw_charge_bar`); the optional `connector_scene` is loaded once on ready.
- **Hit Detection & Combos**: Multi-hit attack combos and damage dispatching. `HitDetection` uses `Area3D` hitboxes, not shape queries: unarmed attacks use the `LeftHandHitbox`/`RightHandHitbox` bone attachments in `player.tscn`; a melee weapon must have a child `Area3D` named **`Hitbox`** (with its `CollisionShape3D`). Hitboxes only `monitoring` during attack locomotion nodes, and any ancestor of a hit body that defines `register_weapon_hit(equipment: Node, hit_node: Node)` is notified once per swing.
- **Look-at ownership**: `Player.set_look_at_target(target: Node3D)` is the single writer of the spine `LookAtModifier3D` (pass `null` to clear). `HeldObject` calls it on pickup/drop and `Bow` while `Bow/ArcheryLocomotion` is active.
- **Bow & Rifle**: `Bow` reacts to `Player.locomotion_node_changed` (`Bow/BowDrawArrow` plays the draw sound, `Bow/BowFireArrow` duplicates the template `Arrow` child and launches it along `ProjectileRaycast`). `Arrow` drops its shooter collision exception after 0.15 s and frees itself after `lifetime`. `Rifle` loops the firing spine emote while shoot is held.

### 4. Inventory & Radial Menu (`Inventory`, `RadialMenu`)
- Circular weapon/tool selection menu activated by holding assigned keys or controller D-Pad.
- Quick weapon cycling (`last_weapon` / `next_weapon`).
- Extensible custom item provider callback for vehicle radios or contextual menus. Items are Dictionaries with `display_name` and `icon` (plus `item` for equipment); a `custom_item_provider` returns the same shape so the addon never knows about stations.
- `Inventory.equipment` is a typed `Array[Equipment]`; `get_equipment_by_type(type) -> Equipment`, and `equipment_changed` fires after every change (`cycle_weapon`, `equip_from_backpack`, `unequip_all`, `Equipment.equip`). Each `BoneAttachment3D` holds exactly one `Equipment`; stowed attachments are hidden children of `Inventory`.
- Hold detection uses the `HoldTimer` in `inventory.tscn` (`wait_time` = hold threshold); a release before timeout cycles, a timeout opens the menu.

### 5. Multi-Platform Contextual Controls (`Controls`)
- Adaptive input icons and button hints supporting:
  - **Keyboard & Mouse**
  - **Microsoft (Xbox)**
  - **Sony (PlayStation)**
  - **Nintendo (Switch)**
  - **Touch Screen**
- Real-time contextual action labels that adapt dynamically to the player's active locomotion state.
- `Controls` (class_name) registers every addon action from its `Controls.ACTIONS` table at runtime (keys, joypad buttons/axes, mouse buttons, deadzone), so the addon stays drop-in with no `project.godot` edits. Actions a project already defines are left untouched; the engine's built-in `ui_*` actions are only extended (joypad A / D-pad). The unused `emote` action is no longer registered.
- Device button textures come from per-vendor `Texture2D` lookups (`_vendor_textures`) applied in one loop; keyboard-only and joypad-only hints toggle visibility as a group, and `update_input_ui()` runs from the `current_input_type` setter before `input_type_changed` is emitted.

### 6. Stamina System (`Stamina`)
- Modular drain and recovery rates for sprinting, climbing, swimming, diving (breath meter), and gliding.
- Exhaustion state with heavy-breathing locomotion recovery.
- Inspector toggles to enable or disable stamina constraints. The hide delay is the `Stamina/Timer` node's `wait_time` in `player.tscn` (its `timeout` is wired to `hide`).
- **WeatherFX interop (optional)**: When the `weather_fx` addon is present, precipitation is read via a soft lookup (`Player.get_precipitation_strength()`) — the addon remains fully functional without it. The player scene root belongs to the `Player` group so interoperating addons can find it with an O(1) group lookup.

### 6b. Driving, Focus & Water Splash (`Driving`, `Focus`, `WaterSplash`)
- **Vehicle contract** (duck typed; the addon does not depend on project vehicle scripts): the vehicle calls `player.state_machine.travel(..., DRIVING)` after `set_driver(player)`; the `Driving` state then calls `vehicle.set_drive_input(accelerate: bool, brake: bool, handbrake: bool, steer: float)` every physics frame while the Player is seated and `vehicle.set_driver(null)` when the driver gets out. The drivetrain (gears, RPM, wheel forces, steering, downforce) belongs to the vehicle; see `scenes/honda_crv.gd`. Optional `DriverSeat`, `EnterCar`/`ExitCar` markers position the Player. `DrivingUI` shows from `Player.state_changed`.
- **Focus**: candidates are bodies in the `Focusable` group overlapping the `TargetDetection` area; a target that leaves the area is dropped after `Focus/TargetLossTimer` elapses. Lock-on is disabled while a firearm is equipped (`Inventory.equipment_changed`). Put a `Marker3D_FocusTarget` on a body to set its focus point.
- **WaterSplash**: `emitters: Array[GPUParticles3D]` is exported from `water_splash.tscn`; the splash frees itself once every emitter's `finished` signal has fired.

### 7. Debug HUD & In-Game Settings (`Debug`, `Settings`, `AudioSettings`, `VideoSettings`)
- **Debug Telemetry**: State, equipment, perspective and FPS read-outs refreshed at 10 Hz by a `Timer` in `debug.tscn` while the HUD is visible (toggle with `F3`; only the multiplayer authority reacts). The click-to-move target is marked by the hidden `NavigationMarker` sphere in the scene, which hides itself from `Player.navigating_changed`.
- **Menu base class** (`PlayerMenuLayer`): `Pause`, `Settings`, `AudioSettings`, `VideoSettings` and `LobbyManager` extend it. It owns `player`, `focus_on_show` (the control focused when the menu opens, set in each scene), `show_menu()`/`hide_menu()` (which set `player.is_paused` and the mouse mode) and closes on the `start` action. Subclasses only hold their button handlers.
- **Split Settings Menu**:
  - **Audio Settings** (`AudioSettings`): Volume sliders and step buttons for `Dialog`, `Menu`, `Music`, and `SFX` buses. Slider `value_changed` applies the bus volume immediately; the file is written on `drag_ended` and when the menu closes, not on every tick. The bus name and the slider are bound in the scene's `[connection]` blocks, so one handler serves all four rows.
  - **Video Settings** (`VideoSettings`): Controls for `VSYNC`, `MSAA`, `SSAA`, `FXAA`, `SSRL`, `TAA`, and `FSR`. `SSAA` and `FSR` both drive the viewport's 3D scaling, so picking one resets the other (control and saved value). The MSAA/SSAA value tables live only in `PlayerSettingsResource`.
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

## 📦 Installation

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
   │       │   ├── controls.tscn
   │       │   └── ...
   │       ├── scripts/
   │       └── tests/
   ├── project.godot
   └── ...
   ```
3. Open your project in **Godot 4.8+**.
4. Go to **Project > Project Settings > Plugins** and toggle the **Enable** checkbox next to **3D Player Controller**.

The addon needs no `project.godot` edits. The Steam lobby UI and the `Loading` screen are inside `addons/3d_player_controller/scenes/` and work without GodotSteam installed.

### Option 2: Download Release Zip

1. Download `3d_player_controller-vX.Y.Z.zip` from the [Releases](https://github.com/kirbycope/godot-3d-player-controller-v3/releases) page.
2. Extract the `3d_player_controller` folder directly into your project's `addons/` directory.

---

## 🎮 Interactive Demo Scene

Open and run **`res://addons/3d_player_controller/scenes/demo/demo.tscn`** to explore the entire locomotion, combat, and interaction sandbox:
- **Playground Arena**: Features a courtyard, climbable walls, slopes/ramps, high towers for paragliding, and a water pool for swimming.
- **Quick Teleports**: Instantly jump to the Glider Tower, Water Pool, Climbing Wall, or Main Courtyard.
- **Full Debug HUD**: Press `F3` at any time to open the complete debug telemetry and feature toggles panel (state, speed, stamina, perspective, flight, ragdoll, etc.).

---

## 🚀 Quick Start

### 1. Instantiate the Player Scene

Drag and drop the ready-to-use Player scene into your level:

```text
res://addons/3d_player_controller/scenes/player.tscn
```

### 2. Scene Setup Requirements

- **Floors & Walls**: Ensure geometry has collision shapes (`CollisionShape3D` or `CSGBox3D` with `use_collision = true`).
- **Water Bodies**: Add an `Area3D` with collision shapes in the **`WATER`** group and call `player.enter_water(area)` / `player.exit_water(area)` on `body_entered`/`body_exited`.
- **Lighting & Camera**: The Player scene includes its own `Camera3D` and `SpringArm3D`.

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
| **Radial Menu / Prev Weapon** | `J` (Hold) | `D-Pad Left` (Hold) |
| **Radial Menu / Next Weapon** | `L` (Hold) | `D-Pad Right` (Hold) |
| **Toggle Perspective** | `F5` | `View / Back` |
| **Debug HUD** | `F3` | — |
| **Pause Menu** | `Escape` | `Start` |
| **Skateboard Dismount** (`whistle`) | `K` | `D-Pad Down` |

All of the above are registered at runtime from `Controls.ACTIONS` when missing from the project's InputMap; the old `emote` (`M`) action was removed.

---

## 🛠️ Adding New Mixamo Animations

To prepare and import custom Mixamo animations with Root Motion:

1. Log into [Mixamo](https://www.mixamo.com/) and select the **Y Bot** character.
2. Search for and download your desired animation:
   - Format: **FBX Binary (.fbx)**
   - Skin: **Without Skin**
   - Frames per Second: **30** or **60**
3. Move the downloaded `.fbx` into `addons/3d_player_controller/assets/mixamo/animations/source/`.
4. Process root motion using the Blender script:
   ```bash
   blender --background --python tools/bake_root_motion.py
   ```
5. In Godot, reimport the resulting `.glb` as an **Animation Library** retargeted to `mixamo_root_bone_map.tres`.
6. Open `player.tscn`, select `AnimationPlayer`, and load the animation into the library.

---

## 🧪 Testing

The controller includes an automated test suite powered by [GUT (Godot Unit Test)](https://github.com/bitwes/Gut).

### Running Tests Headless (CLI)

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://addons/3d_player_controller/tests -gexit
```

### Running Tests in Editor

1. Open the **GUT** panel at the bottom of the Godot editor.
2. Select directory `res://addons/3d_player_controller/tests/`.
3. Click **Run All**.

---

## 🎨 Assets

| Folder | Source | License |
|---|---|---|
| `assets/game_icons/` | [game-icons.net](https://game-icons.net/) (authors listed in the `.txt` file next to each icon, e.g. Lorc) | CC BY 3.0 |
| `assets/kenney_nl/` (incl. `Lobby Icons/`, copied from Kenney's Game Icons pack) | [Kenney](https://www.kenney.nl/) | CC0 |
| `assets/quaternius/` | [Quaternius](https://quaternius.com/) | CC0 1.0 |
| `assets/tommusic/` | [TomMusic](https://tommusic.itch.io/) | Not stated (the pack's `ReadMe.txt` contains no license) |
| `assets/mixamo/` | [Adobe Mixamo](https://www.mixamo.com/) | Adobe Mixamo terms |

---

## 📄 License

MIT License.
