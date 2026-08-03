extends Node

## Does a one-way platform reliably let a RISING player through?
##
##   godot --headless --path <project> res://tests/PassthroughProbe.tscn
##
## Always exits 0. This characterises, it does not gate.
##
## THE QUESTION
## ------------
## The clock probe caught a hop reading:
##
##   flight  solved 1013.5 ms | real 227.8 ms
##   rise    solved 190.0 px  | actual 184.0 px
##
## The player was caught on the way UP, 228ms into a 1013ms arc, and came to
## rest 6px BELOW where they should sit on that platform. A one-way platform
## stopped a body it was supposed to pass. Roughly 1 hop in 55.
##
## THE HYPOTHESIS, WHICH THIS EXISTS TO TEST RATHER THAN ASSUME
## -----------------------------------------------------------
## platform.gd sets one_way_collision_margin = 8.0. At 120Hz a body moving at
## 960 px/s covers 8.0px per physics step, and the game routinely launches
## faster than that: a one-tier hop at 112 BPM leaves at about 906 px/s, and a
## short quantised flight or a two-tier PERFECT can exceed 2000. If the per-step
## travel matters, there will be a SPEED THRESHOLD above which the player snags,
## and it should be visible as a sharp edge rather than a gradual drift.
##
## If instead snagging is scattered across all speeds, the margin is the wrong
## suspect and the cause is elsewhere.
##
## Sweeping the speed is the point. A single launch cannot tell a threshold from
## bad luck.

const PlatformScene: PackedScene = preload("res://scenes/Platform.tscn")

## Height of the test platform above the launch point. Matches TIER_RISE so the
## geometry is the one the game actually uses.
const PLATFORM_ABOVE: float = Tuning.TIER_RISE

## Speed sweep, in pixels per second, and how many launches per speed.
##
## Spans the whole range the solver produces: about 900 for a relaxed one-tier
## hop up to about 2100 for the shortest quantised flight.
const SPEED_FROM: float = 600.0
const SPEED_TO: float = 2200.0
const SPEED_STEP: float = 50.0
const TRIALS: int = 6

# --- Phase two: horizontal motion -------------------------------------------
#
# Phase one found nothing. A body rising straight up passes cleanly at every
# speed the game can produce, so per-step travel through the one-way shape is
# NOT the cause and the margin is not the suspect.
#
# The obvious difference between that probe and a real hop is that a real player
# is steering. Air speed tops out at 620 px/s, which is 5.2px of sideways travel
# per physics step, and a body arriving at a platform edge diagonally meets a
# CORNER rather than a face. One-way collision is decided from the direction of
# motion against the shape's normal, and a mostly-sideways motion with a small
# upward component is a different question from a purely upward one.
#
# So phase two sweeps horizontal speed against launch offset, walking the body
# across the platform's edge, which is the geometry phase one could not produce.

## Horizontal speeds to try, up to Tuning.AIR_SPEED.
const H_SPEEDS: Array[float] = [0.0, 200.0, 400.0, 620.0]

## Launch x offsets from the platform's centre, in pixels.
##
## Platform half-width is 78 and the body radius is 22, so the interesting band
## is roughly 56 to 100 either side: inside that the body starts under the
## platform, outside it starts clear. The sweep covers well past both.
const OFFSET_FROM: float = -160.0
const OFFSET_TO: float = 160.0
const OFFSET_STEP: float = 20.0

## Vertical speeds for phase two. Three points across the real range rather than
## the full sweep, because the grid is already large.
const V_SPEEDS: Array[float] = [900.0, 1400.0, 2000.0]

var _player: CharacterBody2D
var _platform: Node2D


func _ready() -> void:
	print("=== Bounce Ascent one-way passthrough probe ===")
	print("- launching a body UP through a one-way platform %.0fpx above it"
		% PLATFORM_ABOVE)
	print("- physics step %.2f ms, one-way margin %.1f px"
		% [1000.0 / float(Engine.physics_ticks_per_second), 8.0])
	await _build()
	await _sweep()
	await _sweep_horizontal()
	print("---")
	print("probe complete")
	get_tree().quit(0)


func _build() -> void:
	# A bare body and a bare platform, with no Game scene, no Conductor and no
	# audio. The question is purely about collision, and anything else in the
	# scene would be a variable this probe cannot control.
	_player = CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	_player.add_child(shape)
	_player.collision_layer = 1
	_player.collision_mask = 2
	add_child(_player)

	_platform = PlatformScene.instantiate()
	add_child(_platform)
	await get_tree().physics_frame


func _sweep() -> void:
	var first_snag := -1.0
	var snag_speeds: Array[float] = []
	var clean_speeds: Array[float] = []

	var speed := SPEED_FROM
	while speed <= SPEED_TO:
		var snags := 0
		for _t in TRIALS:
			if await _launch_once(speed):
				snags += 1
		if snags > 0:
			snag_speeds.append(speed)
			if first_snag < 0.0:
				first_snag = speed
			print("    %6.0f px/s  (%.1f px/step)  SNAGGED %d of %d"
				% [speed, speed / float(Engine.physics_ticks_per_second),
					snags, TRIALS])
		else:
			clean_speeds.append(speed)
		speed += SPEED_STEP

	print("---")
	print("    clean at %d speeds, snagged at %d" % [clean_speeds.size(), snag_speeds.size()])
	if snag_speeds.is_empty():
		print("    NO SNAG anywhere in %.0f to %.0f px/s."
			% [SPEED_FROM, SPEED_TO])
		print("    The margin hypothesis is NOT supported: whatever caught the")
		print("    player in the real run needs something this probe does not")
		print("    reproduce (horizontal motion, a moving platform, a recycle).")
		return

	print("    first snag at %.0f px/s (%.1f px per physics step)"
		% [first_snag, first_snag / float(Engine.physics_ticks_per_second)])
	# A sharp edge supports the per-step-travel explanation; a scatter refutes it.
	var contiguous := true
	for s in clean_speeds:
		if s > first_snag:
			contiguous = false
			break
	if contiguous:
		print("    Every speed above the threshold snags and none below it do.")
		print("    That is a THRESHOLD, which supports per-step travel as the cause.")
	else:
		print("    Snags are SCATTERED, not a clean threshold, so per-step travel")
		print("    alone does not explain it.")


## Phase two: rise diagonally, crossing the platform's edge.
func _sweep_horizontal() -> void:
	print("---")
	print("- phase two: rising WITH horizontal motion, across the platform edge")
	print("  (platform half-width %.0f px, body radius 22 px, air speed max %.0f)"
		% [Tuning.PLATFORM_HALF_WIDTH, Tuning.AIR_SPEED])

	var snags := 0
	var trials := 0
	var worst_rise := 999.0
	var worst_desc := ""

	for v in V_SPEEDS:
		for h in H_SPEEDS:
			var offset := OFFSET_FROM
			while offset <= OFFSET_TO:
				trials += 1
				var rose := await _launch_diagonal(v, h, offset)
				# A snag is an ascent that stopped anywhere short of clearing
				# the platform, given this launch had the energy to clear it.
				if rose >= 0.0 and rose < worst_rise:
					worst_rise = rose
					worst_desc = "v=%.0f h=%.0f offset=%+.0f" % [v, h, offset]
				if rose >= 0.0 and rose < PLATFORM_ABOVE + 10.0:
					snags += 1
					print("    SNAG  v=%.0f h=%.0f offset=%+.0f  rose only %.1f px"
						% [v, h, offset, rose])
				offset += OFFSET_STEP

	print("---")
	print("    %d of %d diagonal launches snagged" % [snags, trials])
	if snags == 0:
		print("    lowest ascent was %.1f px (%s), which cleared the platform"
			% [worst_rise, worst_desc])
		print("    Horizontal motion does NOT reproduce it either. The cause")
		print("    needs something still absent here: a MOVING platform sliding")
		print("    into the body, a horizontal wrap, or a pooled platform being")
		print("    repositioned mid-flight.")


## One diagonal launch. Returns how far the body rose, or -1 if this launch
## could not have cleared the platform anyway and so proves nothing.
func _launch_diagonal(v_speed: float, h_speed: float, offset: float) -> float:
	var apex := (v_speed * v_speed) / (2.0 * Tuning.GRAVITY)
	if apex < PLATFORM_ABOVE + 40.0:
		return -1.0

	_platform.setup(1, Vector2(360.0, -PLATFORM_ABOVE), 1.0,
		Tuning.PlatformType.NORMAL, 0.0)
	_player.global_position = Vector2(360.0 + offset, 0.0)
	_player.velocity = Vector2(h_speed, -v_speed)
	await get_tree().physics_frame

	var highest := 0.0
	for _i in 40:
		_player.velocity.y += Tuning.GRAVITY / float(Engine.physics_ticks_per_second)
		# Horizontal speed is held, which is what a player leaning on the stick
		# produces; air friction only applies when they let go.
		_player.velocity.x = h_speed
		_player.move_and_slide()
		highest = minf(highest, _player.global_position.y)
		await get_tree().physics_frame

	return -highest


## One launch. Returns true if the body was stopped short of clearing the
## platform.
func _launch_once(speed: float) -> bool:
	# Rebuild the platform each trial so no state carries between launches.
	_platform.setup(1, Vector2(360.0, -PLATFORM_ABOVE), 1.0,
		Tuning.PlatformType.NORMAL, 0.0)
	_player.global_position = Vector2(360.0, 0.0)
	_player.velocity = Vector2(0.0, -speed)
	await get_tree().physics_frame

	var highest := 0.0
	# Long enough for the whole ascent at the slowest speed in the sweep.
	for _i in 60:
		_player.velocity.y += Tuning.GRAVITY / float(Engine.physics_ticks_per_second)
		_player.move_and_slide()
		highest = minf(highest, _player.global_position.y)
		await get_tree().physics_frame

	var rose := -highest

	# CORRECTED. This originally measured only the UNDERSIDE catch, at
	# PLATFORM_ABOVE - half_height - radius = 158px, and called anything higher a
	# clean pass. The real failure happens at the TOP surface: the body caught in
	# the game was at 182.9px, its centre 15px clear of the surface while its
	# lower half was still 7px under it. This probe scored that as success, which
	# is why it "refuted" a hypothesis that was closer to right than it looked.
	#
	# A clean pass now means clearing the resting height entirely.
	var blocked_at := PLATFORM_ABOVE

	# Free-flight apex for this launch, so a slow launch that simply did not
	# reach the platform is not miscounted as a snag.
	var apex := (speed * speed) / (2.0 * Tuning.GRAVITY)
	if apex < PLATFORM_ABOVE + 40.0:
		return false

	return rose < blocked_at + 20.0

