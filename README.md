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
- **Climbing**: Raycast-assisted wall detection, ledge hopping, and wall climbing.
- **Hanging & Shimmy**: Braced and free-hang wall gripping with directional shimmy.
- **Swimming & Fast Swimming**: Water volume detection (`WATER` group), buoyancy, and surface swimming.
- **Paragliding**: Deployable glider with steering control and mid-air cancel.
- **Skateboarding**: Push acceleration, fast push, jumping, and dismounting.
- **Flying**: 3D spatial flying with vertical ascending/descending.
- **Sitting & Ragdoll**: Physical bone ragdoll simulation with get-up recovery.
- **Driving**: Seamless vehicle entry and exit integration.

### 2. First & Third Person Camera (`Camera`)
- Dynamic toggle between **First-Person** and **Third-Person** perspectives.
- SpringArm collision avoidance preventing clipping through geometry.
- Configurable mouse sensitivity, gamepad stick sensitivity, and axis inversion.
- Smooth rotation interpolation and camera smoothing.

### 3. Equipment, Combat & Interactions (`Equipment`, `HeldObject`)
- **Weapon Classes**: 1H Swords, 2H Greatswords (with tree-logging animation), Sword & Shield, Daggers, Axes, Staffs, and Rifles.
- **Bow & Arrow Mechanics**: Aiming, string draw, charge timing, arrow trajectory, and projectile firing.
- **Object Manipulation**: Pick up, carry, aim, rotate, and throw `RigidBody3D` objects or companion bodies.
- **Hit Detection & Combos**: Multi-hit attack combos and damage dispatching.

### 4. Inventory & Radial Menu (`Inventory`, `RadialMenu`)
- Circular weapon/tool selection menu activated by holding assigned keys or controller D-Pad.
- Quick weapon cycling (`last_weapon` / `next_weapon`).
- Extensible custom item provider callback for vehicle radios or contextual menus.

### 5. Multi-Platform Contextual Controls (`Controls`)
- Adaptive input icons and button hints supporting:
  - **Keyboard & Mouse**
  - **Microsoft (Xbox)**
  - **Sony (PlayStation)**
  - **Nintendo (Switch)**
  - **Touch Screen**
- Real-time contextual action labels that adapt dynamically to the player's active locomotion state.

### 6. Stamina System (`Stamina`)
- Modular drain and recovery rates for sprinting, climbing, swimming, and gliding.
- Exhaustion state with heavy-breathing locomotion recovery.
- Inspector toggles to enable or disable stamina constraints.

### 7. Debug HUD & In-Game Settings (`Debug`, `Settings`)
- Real-time state visualizer, active perspective indicator, and live FPS counter (toggle with `F3`).
- Audio bus volume controls, mouse sensitivity sliders, and keybindings menu.

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
   │       ├── resources/
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
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://addons/3d_player_controller/tests/ -gexit
```

### Running Tests in Editor

1. Open the **GUT** panel at the bottom of the Godot editor.
2. Select directory `res://addons/3d_player_controller/tests/`.
3. Click **Run All**.

---

## 📄 License

MIT License.
