extends GutTest

## Purpose: the swim animations keep the hand-tuned Hips height that decides how high the player
## floats in water, rather than the raw Mixamo capture.
##
## The three swim animations import from .glb with save_to_file enabled, so each one has a .tres
## beside it that looks like a generated artifact. It is not. The Hips position track in each is
## offset by hand in the editor to sit the body at the waterline, and "Swimming To Edge" carries
## hand-tuned arm and leg rotation curves as well. Re-importing the .glb gives back the untuned
## capture, so that work lives only in the .tres.
##
## It has been lost twice. The Hips height was set to 1.2, came back as the raw 0.69952834, was set
## again to 1.0995283, and came back as 0.69952834 a second time in the Asset Library restructure.
## Neither loss was the importer: a headless re-import leaves an existing save_to_file resource
## alone even with a cold .godot cache, after a move, with a stale uid, with importer_version
## bumped, and with the source .glb altered. Both losses were a file-level copy winning, which is
## what a restructure, a mirror or tools/pull_addons.py does. Nothing failed at the time, so the
## next person to notice was the player, in the water, months later.
##
## This is that alarm. It reads the resource the game actually loads.

const ANIMATIONS_PATH: String = "res://addons/3d_player_controller/assets/mixamo/animations/root_motion"

const HIPS_TRACK: String = "%GeneralSkeleton:Hips"

## Hips height at the first key: what the animation is tuned to, and what a raw re-import gives back.
const SWIM_HEIGHTS: Dictionary = {
	"Swimming": {"tuned": 1.0995283, "raw": 0.69952834},
	"Swimming At Edge": {"tuned": 1.2018158, "raw": 1.4994758},
	"Swimming To Edge": {"tuned": 1.1010405, "raw": 1.4610405},
}

## Loose enough to survive a re-save rounding the float, tight enough that a raw capture fails.
const TOLERANCE: float = 0.001

## The most any key rides from the first one. The real stroke bobs by 0.041 at most and the smallest
## offset in the table is 0.298, so this sits clear of the bob and well under a stranded key.
const MAXIMUM_BOB: float = 0.15


func test_every_swim_animation_keeps_its_tuned_hips_height() -> void:
	for name: String in SWIM_HEIGHTS:
		var expected: Dictionary = SWIM_HEIGHTS[name]
		var animation: Animation = load("%s/%s.tres" % [ANIMATIONS_PATH, name]) as Animation
		assert_not_null(animation, "%s.tres should load as an Animation" % name)
		if animation == null:
			continue

		var height: float = _first_hips_height(animation)
		assert_almost_eq(
			height,
			float(expected["tuned"]),
			TOLERANCE,
			"%s floats at %f. Tuned is %f; %f is the raw Mixamo capture, so the hand edit was overwritten." % [
				name, height, expected["tuned"], expected["raw"],
			]
		)


func test_the_whole_hips_track_is_offset_and_not_just_the_first_key() -> void:
	# The offset is applied to the track, so every key moves together and the body keeps its natural
	# bob. Offsetting key zero alone would satisfy the test above and still swim wrong for the rest
	# of the loop, with the remaining keys stranded a full offset away.
	for name: String in SWIM_HEIGHTS:
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
			MAXIMUM_BOB,
			"%s has a key %f from its first. The offset belongs on the whole track, not one key." % [name, furthest]
		)


## The Y of the first key of the Hips position track.
func _first_hips_height(animation: Animation) -> float:
	var track: int = _hips_position_track(animation)
	if track < 0 or animation.track_get_key_count(track) == 0:
		return NAN
	return (animation.track_get_key_value(track, 0) as Vector3).y


func _hips_position_track(animation: Animation) -> int:
	for track: int in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		if str(animation.track_get_path(track)) == HIPS_TRACK:
			return track
	return -1
