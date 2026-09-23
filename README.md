![Preview](addons/3d_player_controller/assets/godot-3d-player-controller-addon.png)

# 3D Player Controller for Godot 4.8+

A modular 3D character controller: a locomotion finite state machine on `CharacterBody3D` and
`AnimationTree` with root motion, first and third person cameras, equipment and combat, an
inventory and spell system, and Steam multiplayer.

**[Read the full documentation](addons/3d_player_controller/README.md)**, which ships with the addon so it is
there however you installed it.

Play the demo in a browser at <https://timothycope.com/godot-3d-player-controller-addon/>.

## This repository

It uses the layout the [Godot Asset Library](https://docs.godotengine.org/en/stable/community/asset_library/submitting_to_assetlib.html) expects, so it is both the addon and a
project you can open and edit it in:

```
project.godot                 the demo project, which is this repository
addons/3d_player_controller/  the addon itself
addons/controls/              the on-screen input hints
addons/gut/                   the test runner
```

`addons/gut/` is not committed, and neither is any other addon the manifest in `tools/addons.json` names:
`python tools/pull_addons.py` fetches them after cloning, pinned to the commits in `tools/addons.lock.json`,
and CI runs the same pull before the tests. GUT is a third-party entry, taken from its release tag and never
pushed to.

Clone it, open `project.godot` in Godot, and run the demo scene. The addon is mounted at
`res://addons/3d_player_controller/` exactly as it is in a game, so it is edited in place with nothing copied
anywhere first. Installing through the Asset Library takes `addons/` and skips the root
`project.godot` as a conflict, which is why that file can live here harmlessly.

## Installing it in a game

This repository does not commit the addons it depends on: `addons/controls/` and `addons/gta/` are
fetched, not checked in, so after cloning run

```bash
python tools/pull_addons.py
```

before opening the project, or nothing loads.

Copy `addons/3d_player_controller/` into your project's `addons/`. See the
[addon's README](addons/3d_player_controller/README.md) for what it needs and how to use it.

## Releases and CI

A pull request merged into `main` cuts a release, and nothing else does short of a manual run:
`.github/workflows/release-addon.yml` publishes `addons/3d_player_controller/` as
`3d_player_controller-vX.Y.Z.zip` on the [Releases](https://github.com/kirbycope/godot-3d-player-controller-addon/releases)
page, then moves `config/version` in `project.godot` and `version` in the addon's `plugin.cfg` on to the next
development version. `.github/workflows/gut-tests.yml` runs the tests on every push and pull request.
`pull_addons.py` exits 1 when any addon fails to pull, so CI stops there rather than testing a partial `addons/`,
and a run whose JUnit report holds no test at all fails the job as a failing test would.
