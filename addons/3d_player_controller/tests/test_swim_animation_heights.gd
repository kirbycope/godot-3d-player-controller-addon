extends GutTest

## Purpose: every animation saved beside its .glb still holds the pose it was last given, rather
## than the raw Mixamo capture.
##
## Each animation imported with Save to File leaves a .tres next to its .glb that looks generated.
## It is not always. Some are edited by hand afterwards and the edit lives only in the .tres,
## because re-importing the .glb gives back the raw capture. The three swim animations are the
## current case: the %GeneralSkeleton:Hips position track in each is offset to sit the body at the
## waterline.
##
## Those heights were lost twice. Set to 1.2, back to the raw 0.69952834; set to 1.0995283, back to
## 0.69952834 again in the Asset Library restructure. The player swam 0.65 m under the surface
## instead of 0.25 m and was invisible from the ordinary camera. The importer is not the hazard: a
## headless re-import leaves an existing Save to File resource alone with a cold .godot cache, after
## a move, with a stale uid, with importer_version bumped and with the source .glb altered. A
## file-level copy is, so a restructure, a mirror or tools/pull_addons.py.
##
## The table below covers the whole folder rather than the three that were noticed, because the
## folder is the unit at risk: whatever wipes one wipes its neighbours in the same pass. A diff
## cannot sort real work from noise here, only magnitude can. That same restructure also rewrote 16
## other files, every one of them a rotation difference of about 1e-7 from a re-export with no
## position change at all, against 0.298 to 0.4 metres for the three that mattered.
##
## There is no raw reference to compare against at run time: with Save to File enabled the .glb's
## AnimationLibrary hands back the .tres itself, the very same instance, so the expected values have
## to be recorded. Tuning another animation means changing its number here, and the failure says so.

const ANIMATIONS_PATH: String = "res://addons/3d_player_controller/assets/mixamo/animations/root_motion"

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
	"Swimming": 1.0995283,
	"Swimming At Edge": 1.2018158,
	"Swimming To Edge": 1.1010405,
	"Sword and Shield Jump Forward": NAN,
	"Sword and Shield Jump": NAN,
	"Throw": 0.9800626,
}

## The swim animations hold the body flat at the surface, so their Hips barely move. The others
## jump, flip and slide, and one of them rides 0.86 up, so a shared ceiling would mean nothing.
const SWIM_ANIMATIONS: PackedStringArray = ["Swimming", "Swimming At Edge", "Swimming To Edge"]

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


func test_the_swim_offsets_are_on_the_whole_track_and_not_one_key() -> void:
	# The offset is applied to the track, so every key moves together and the body keeps its bob.
	# Offsetting key zero alone would satisfy the test above and still swim wrong for the rest of
	# the loop, with the remaining keys stranded a full offset away.
	for name: String in SWIM_ANIMATIONS:
		var animation: Animation = load("%s/%s.tres" % [ANIMATIONS_PATH, name]) as Animation
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
