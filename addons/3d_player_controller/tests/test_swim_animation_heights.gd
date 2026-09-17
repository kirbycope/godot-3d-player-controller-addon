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

## Y of the first key of each animation's Hips position track. NAN records that the animation has no
## such track at all, which most of the jumps do not, carrying their lift on Root instead.
const EXPECTED_HIPS_HEIGHT: Dictionary = {
	"Backflip": 0.9305699,
	"Bow Standing Jump Running To Run Forward": NAN,
	"Bow Standing Jumping": NAN,
	"Driving": 0.6188195,
	"Entering Car": 0.9920238,
	"Great Sword Jump Forward": NAN,
	"Great Sword Jump": NAN,
	"Jumping Up": NAN,
	"Pistol Jump Forward": NAN,
	"Pistol Jump": NAN,
	"Ready To Cast Spell Standing Idle": 0.8914642,
	"Rifle Jump Forward": NAN,
	"Rifle Jump Up": NAN,
	"Running Forward Flip": 0.9208747,
	"Running Jump": NAN,
	"Running Slide": 0.9207888,
	"Running": 0.9219201,
	"Sprint": 0.8830373,
	"Sword and Shield Jump Forward": NAN,
	"Sword and Shield Jump": NAN,
	"Throw": 0.9800626,
}

## The swim animations hold the body flat at the surface, so their Hips barely move. The others
## jump, flip and slide, and one of them rides 0.86 up, so a shared ceiling would mean nothing.
const EXPECTED_TUNED_HEIGHT: Dictionary = {
	"Swimming": 1.0995283,
	"Swimming At Edge": 1.2018158,
	"Swimming To Edge": 1.1010405,
}

## Loose enough to survive a re-save rounding the float, tight enough that a raw capture fails: the
## smallest offset being guarded is 0.298.
const TOLERANCE: float = 0.001

## The most any swim key rides from the first. The real stroke bobs by 0.041 at most.
const MAXIMUM_SWIM_BOB: float = 0.15


func test_the_folder_holds_exactly_the_animations_this_test_knows_about() -> void:
	# Otherwise a new animation could be added, never be checked, and be wiped in the same silence.
	var found: PackedStringArray = _saved_animation_names()
	found.sort()
	var expected: PackedStringArray = PackedStringArray(EXPECTED_HIPS_HEIGHT.keys())
	expected.sort()
	assert_eq(
		found,
		expected,
		"Add the new animation to EXPECTED_HIPS_HEIGHT with the Hips height it should keep."
	)


func test_every_saved_animation_keeps_its_hips_height() -> void:
	for name: String in EXPECTED_HIPS_HEIGHT:
		var animation: Animation = load("%s/%s.tres" % [ANIMATIONS_PATH, name]) as Animation
		assert_not_null(animation, "%s.tres should load as an Animation" % name)
		if animation == null:
			continue

		var track: int = _hips_position_track(animation)
		var expected: float = EXPECTED_HIPS_HEIGHT[name]

		if is_nan(expected):
			assert_eq(track, -1, "%s has gained a %s track; record its height" % [name, HIPS_TRACK])
			continue

		assert_gt(track, -1, "%s has lost its %s track entirely" % [name, HIPS_TRACK])
		if track < 0:
			continue

		var height: float = (animation.track_get_key_value(track, 0) as Vector3).y
		assert_almost_eq(
			height,
			expected,
			TOLERANCE,
			"%s sits at %f rather than %f. Either the hand edit was overwritten, or it was retuned and this table is stale." % [
				name, height, expected,
			]
		)


func test_the_swim_animations_keep_their_tuned_height() -> void:
	for name: String in EXPECTED_TUNED_HEIGHT:
		var animation: Animation = _tuned(name)
		assert_not_null(animation, "%s should load from tuned/ as an AnimationLibrary" % name)
		if animation == null:
			continue
		var track: int = _hips_position_track(animation)
		assert_gt(track, -1, "%s has lost its %s track" % [name, HIPS_TRACK])
		if track < 0:
			continue
		var height: float = (animation.track_get_key_value(track, 0) as Vector3).y
		assert_almost_eq(
			height,
			float(EXPECTED_TUNED_HEIGHT[name]),
			TOLERANCE,
			"%s floats at %f rather than %f" % [name, height, EXPECTED_TUNED_HEIGHT[name]]
		)


func test_no_swim_animation_is_importer_output_any_more() -> void:
	# The whole point of tuned/: an importer that does not own the file cannot rewrite it. A .tres
	# reappearing beside the .glb means save_to_file was switched back on and the edit is at risk.
	for name: String in EXPECTED_TUNED_HEIGHT:
		assert_false(
			ResourceLoader.exists("%s/%s.tres" % [ANIMATIONS_PATH, name]),
			"%s is importer output again; a cold import will overwrite it" % name
		)


func test_the_swim_offsets_are_on_the_whole_track_and_not_one_key() -> void:
	# The offset is applied to the track, so every key moves together and the body keeps its bob.
	# Offsetting key zero alone would satisfy the test above and still swim wrong for the rest of
	# the loop, with the remaining keys stranded a full offset away.
	for name: String in EXPECTED_TUNED_HEIGHT:
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


## Every animation saved beside its .glb, by name without the extension.
func _saved_animation_names() -> PackedStringArray:
	var names: PackedStringArray = []
	var directory := DirAccess.open(ANIMATIONS_PATH)
	if directory == null:
		return names
	directory.list_dir_begin()
	var file: String = directory.get_next()
	while file != "":
		if not directory.current_is_dir() and file.ends_with(".tres"):
			names.append(file.trim_suffix(".tres"))
		file = directory.get_next()
	directory.list_dir_end()
	return names


func _hips_position_track(animation: Animation) -> int:
	for track: int in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		if str(animation.track_get_path(track)) == HIPS_TRACK:
			return track
	return -1
