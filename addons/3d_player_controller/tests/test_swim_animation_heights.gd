extends GutTest

## Purpose: every animation still holds the pose it was last given, rather than the raw Mixamo
## capture the importer would put back.
##
## An animation imported with Save to File leaves a .tres next to its .glb that looks generated, and
## for most of them it is. Three are not: the %GeneralSkeleton:Hips position track in each swim
## animation is offset by hand to sit the body at the waterline, between 0.298 and 0.4 metres.
##
## That work was lost twice. Set to 1.2, back to the raw 0.69952834; set to 1.0995283, back to
## 0.69952834 again. The player swam 0.65 m under instead of 0.25 m, invisible from the ordinary
## camera. The cause is the importer, and it is worth being exact about how it was pinned down,
## because the obvious experiment says the opposite. Re-importing a small project holding just the
## .glb, its .import and the .tres leaves the file alone, even with a cold .godot cache, after a
## move, with a stale uid and with importer_version bumped. Cloning this repository fresh and
## importing it wipes all three on the first pass. Neither keep_custom_tracks nor marking the track
## imported=false survives it, and an import_script runs with the right offsets but too late, after
## the resource has already been written.
##
## So the swim animations were taken out of the import pipeline. They are hand-owned
## AnimationLibrary resources under tuned/, save_to_file is off for their .glb files, and an
## importer that does not own a file cannot rewrite it. Verified on a fresh clone across a cold
## import and two editor opens.
##
## Everything else is still importer output and still worth watching, so the table covers the whole
## folder rather than the three that were noticed: whatever wipes one wipes its neighbours in the
## same pass. Judge a diff there by magnitude, not by its existence. The restructure that reverted
## the swim heights also rewrote 16 other animations, every one a rotation difference of about 1e-7
## from a re-export, with no position change at all.

const ANIMATIONS_PATH: String = "res://addons/3d_player_controller/assets/mixamo/animations/root_motion"

## The swim animations are hand-owned AnimationLibrary resources here rather than importer output,
## which is what stops a cold import rewriting them. Each holds one animation, named as the .glb's
## was so player.tscn's "Swimming/mixamo_com" still resolves.
const TUNED_PATH: String = "res://addons/3d_player_controller/assets/mixamo/animations/tuned"

const TUNED_ANIMATION: StringName = &"mixamo_com"

const HIPS_TRACK: String = "%GeneralSkeleton:Hips"

## The Hips position track of each animation the importer still owns, as [first key, lowest, highest].
## An empty array records that the animation has no such track, which most of the jumps do not,
## carrying their lift on Root instead.
##
## Lowest and highest are not decoration. Entering Car's hand edit sank the dip as the driver sits
## into the seat from 0.842 to 0.742 and never touched the first key, so a first-key check watched it
## get reverted three times and said nothing.
const EXPECTED_HIPS: Dictionary = {
	"Backflip": [0.9305699, 0.6450410, 1.3755330],
	"Bow Standing Jump Running To Run Forward": [],
	"Bow Standing Jumping": [],
	"Driving": [0.6188195, 0.6188195, 0.6188195],
	"Great Sword Jump Forward": [],
	"Great Sword Jump": [],
	"Jumping Up": [],
	"Pistol Jump Forward": [],
	"Pistol Jump": [],
	"Ready To Cast Spell Standing Idle": [0.8914642, 0.8442172, 0.8951364],
	"Rifle Jump Forward": [],
	"Rifle Jump Up": [],
	"Running Forward Flip": [0.9208747, 0.7412975, 1.7819712],
	"Running Jump": [],
	"Running Slide": [0.9207888, 0.2397544, 0.9444287],
	"Running": [0.9219201, 0.9032632, 0.9703432],
	"Sprint": [0.8830373, 0.8738528, 0.9565051],
	"Sword and Shield Jump Forward": [],
	"Sword and Shield Jump": [],
	"Throw": [0.9800626, 0.9555750, 1.0105404],
}

## The animations taken out of the import pipeline, same shape.
const EXPECTED_TUNED: Dictionary = {
	"Entering Car": [0.9920238, 0.7420000, 1.0130469],
	"Swimming": [1.0995283, 1.0838133, 1.1031445],
	"Swimming At Edge": [1.2018158, 1.1959828, 1.2044084],
	"Swimming To Edge": [1.1010405, 1.0896482, 1.1420684],
}

## Loose enough to survive a re-save rounding the float, tight enough that a raw capture fails: the
## smallest offset being guarded is 0.298.
const TOLERANCE: float = 0.001

## The most any swim key rides from the first. The real stroke bobs by 0.041 at most.
const MAXIMUM_SWIM_BOB: float = 0.15


func test_both_folders_hold_exactly_the_animations_this_test_knows_about() -> void:
	# Otherwise a new animation could be added, never be checked, and be wiped in the same silence.
	assert_eq(_names_in(ANIMATIONS_PATH), _sorted_keys(EXPECTED_HIPS), "Update EXPECTED_HIPS.")
	assert_eq(_names_in(TUNED_PATH), _sorted_keys(EXPECTED_TUNED), "Update EXPECTED_TUNED.")


func test_every_animation_the_importer_owns_keeps_its_hips_track() -> void:
	for name: String in EXPECTED_HIPS:
		_check(load("%s/%s.tres" % [ANIMATIONS_PATH, name]) as Animation, name, EXPECTED_HIPS[name])


func test_every_hand_owned_animation_keeps_its_hips_track() -> void:
	for name: String in EXPECTED_TUNED:
		_check(_tuned(name), name, EXPECTED_TUNED[name])


func test_no_hand_owned_animation_is_importer_output_any_more() -> void:
	# The whole point of tuned/: an importer that does not own a file cannot rewrite it. A .tres
	# reappearing beside the .glb means save_to_file came back on and the edit is at risk again.
	for name: String in EXPECTED_TUNED:
		assert_false(
			ResourceLoader.exists("%s/%s.tres" % [ANIMATIONS_PATH, name]),
			"%s is importer output again; a cold import will overwrite it" % name
		)


func test_the_swim_offsets_are_on_the_whole_track_and_not_one_key() -> void:
	# The offset is applied to the track, so every key moves together and the body keeps its bob.
	# Offsetting key zero alone would satisfy the test above and still swim wrong for the rest of
	# the loop, with the remaining keys stranded a full offset away.
	for name: String in EXPECTED_TUNED:
		if not name.begins_with("Swimming"):
			continue  # Entering Car is meant to dip; only the swim clips hold the body flat.
		var animation: Animation = _tuned(name)
		if animation == null:
			continue
		var track: int = _hips_position_track(animation)
		assert_gt(track, -1, "%s should still animate %s" % [name, HIPS_TRACK])
		if track < 0:
			continue

		var first: float = (animation.track_get_key_value(track, 0) as Vector3).y
		var furthest: float = 0.0
		for key: int in animation.track_get_key_count(track):
			var height: float = (animation.track_get_key_value(track, key) as Vector3).y
			furthest = maxf(furthest, absf(height - first))

		assert_lt(
			furthest,
			MAXIMUM_SWIM_BOB,
			"%s has a key %f from its first. The offset belongs on the whole track, not one key." % [name, furthest]
		)


## The one animation inside a hand-owned library under tuned/.
func _tuned(name: String) -> Animation:
	var library: AnimationLibrary = load("%s/%s.tres" % [TUNED_PATH, name]) as AnimationLibrary
	return library.get_animation(TUNED_ANIMATION) if library != null else null


func _hips_position_track(animation: Animation) -> int:
	for track: int in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		if str(animation.track_get_path(track)) == HIPS_TRACK:
			return track
	return -1


## Checks a Hips track against [first, lowest, highest]; an empty expectation means no track at all.
func _check(animation: Animation, name: String, expected: Array) -> void:
	assert_not_null(animation, "%s should load" % name)
	if animation == null:
		return
	var track: int = _hips_position_track(animation)
	if expected.is_empty():
		assert_eq(track, -1, "%s has gained a %s track; record it" % [name, HIPS_TRACK])
		return
	assert_gt(track, -1, "%s has lost its %s track entirely" % [name, HIPS_TRACK])
	if track < 0:
		return

	var first: float = (animation.track_get_key_value(track, 0) as Vector3).y
	var lowest: float = INF
	var highest: float = -INF
	for key: int in animation.track_get_key_count(track):
		var y: float = (animation.track_get_key_value(track, key) as Vector3).y
		lowest = minf(lowest, y)
		highest = maxf(highest, y)

	var label: String = "%s [first %f, lowest %f, highest %f] against [%f, %f, %f]" % [
		name, first, lowest, highest, expected[0], expected[1], expected[2],
	]
	assert_almost_eq(first, float(expected[0]), TOLERANCE, label)
	assert_almost_eq(lowest, float(expected[1]), TOLERANCE, label)
	assert_almost_eq(highest, float(expected[2]), TOLERANCE, label)


func _sorted_keys(table: Dictionary) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray(table.keys())
	names.sort()
	return names


func _names_in(folder: String) -> PackedStringArray:
	var names: PackedStringArray = []
	var directory := DirAccess.open(folder)
	if directory == null:
		return names
	directory.list_dir_begin()
	var file: String = directory.get_next()
	while file != "":
		if not directory.current_is_dir() and file.ends_with(".tres"):
			names.append(file.trim_suffix(".tres"))
		file = directory.get_next()
	directory.list_dir_end()
	names.sort()
	return names
