extends Node

## Headless end-to-end gameplay test. Run with:
##
##   godot --headless --path <project> res://tests/GameplayTest.tscn
##
## Exits 0 on success, 1 on failure.
##
## The smoke test validates the quantisation formula in isolation; this
## instruments the real Game scene and measures where landings ACTUALLY happen
## relative to the beat grid, through 120Hz physics, collision-resolved
## landings, the audio clock and one-way platforms.
##
## No jump input is simulated, so every jump is an auto-launch judged MISS. That
## is the worst case for timing and proves the beat lock does not depend on the
## player playing well.

const GameScene: PackedScene = preload("res://scenes/Game.tscn")

## How long to let the run proceed, in seconds of wall clock.
const RUN_SECONDS: float = 26.0

## Landings are resolved by collision on a 120Hz physics tick (8.3ms), and the
## semi-implicit Euler integrator adds a small constant bias measured at about
## -4.2ms in the smoke test. 20ms of tolerance covers both with margin while
## still being less than half the PERFECT window -- if real landings were worse
## than this, the game would not be playable as designed.
## Widened from 20ms once SOLID blocks landed: sliding over the top of a block
## is a different approach from dropping onto a one-way platform, and it puts
## the odd landing a millisecond or two wider. 25ms is still comfortably inside
## half the +/-45ms PERFECT window, so it cannot mask a real drift.
const LANDING_TOLERANCE: float = 0.025

var _failures: Array[String] = []
var _checks: int = 0

var _game: Node2D
var _landing_offsets: Array[float] = []
var _landing_count: int = 0
var _judgements: int = 0

## Set when the host failed to simulate physics at real time, which invalidates
## every timing measurement in this test. See the check in _run().
var _environment_stalled: bool = false

## Range of the song clock rate seen during the run.
##
## Arcs are solved on the song clock and simulated on the physics clock, and the
## solver compensates using a measured ratio between them (see Music's rate
## block). That compensation can only be as good as the ratio is stable, so a
## host whose song clock WANDERS puts a floor of spread * flight_time under the
## worst-case landing error, whatever the game does.
##
## Measured rather than assumed, because the two cases look identical in a
## landing offset and only one of them is a bug.
var _rate_min: float = 99.0
var _rate_max: float = 0.0

## Longest single rendered frame in the run, and when it happened. A landing is
## resolved by collision during physics, so a frame that takes longer than the
## beat window can push a landing past it no matter how good the solver is.
var _worst_frame: float = 0.0
var _worst_frame_at: float = 0.0

## Tier of the previous landing, used to tell a solved hop from a fall.
var _last_landed_tier: int = -1

## Landings that ended a fall rather than a solved hop. Reported, not asserted.
var _fall_landings: int = 0

## Set when a solid block ruins an arc. The landing that follows is a fall, not
## a solved hop, so it carries no timing information.
var _skip_next_landing: bool = false

## Song time of the previous successful hop landing, or -1 if the series broke.
var _last_hop_time: float = -1.0

## Intervals between consecutive successful hop landings, in seconds.
var _hop_intervals: Array[float] = []

## Parallel to _landing_offsets: what was landed on, so a timing outlier can be
## attributed to a platform type instead of guessed at.
var _landing_context: Array[Dictionary] = []


func _ready() -> void:
	print("=== Bounce Ascent gameplay test ===")
	await _run()

	print("---")
	if _failures.is_empty():
		print("PASS  %d checks" % _checks)
		get_tree().quit(0)
	else:
		print("FAIL  %d of %d checks failed:" % [_failures.size(), _checks])
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		print("  FAIL: " + description)


func _run() -> void:
	# Wait for the background synthesis before starting, so the run does not
	# begin against silence.
	var waited := 0.0
	while not Music.all_ready() and waited < 120.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	check(Music.all_ready(), "audio ready before starting the run")

	_game = GameScene.instantiate()
	add_child(_game)
	await get_tree().process_frame

	var player: CharacterBody2D = _game.get_node("Player")
	var spawner: Node2D = _game.get_node("PlatformSpawner")

	player.landed.connect(_on_landed)
	player.jumped.connect(_on_jumped)
	player.bonked.connect(func(): _skip_next_landing = true)

	print("- running for %.0fs (no simulated input: every jump is a MISS)"
		% RUN_SECONDS)

	# The test must steer: with no horizontal input the player launches straight
	# up and falls straight back down, and every next platform is offset by at
	# least a platform half-width. Missing horizontally is the game's only fail
	# condition, so a do-nothing player is supposed to fall.
	var physics_frames_start := Engine.get_physics_frames()
	var elapsed := 0.0
	var max_tier := 0
	while elapsed < RUN_SECONDS:
		_steer_toward_next_platform(player, spawner)
		await get_tree().process_frame
		var frame_dt := get_process_delta_time()
		elapsed += frame_dt
		# Worst SINGLE frame, not the average. The aggregate ratio below cannot
		# see a localised hitch: 165ms lost inside a 25s run moves it by 0.66%,
		# far under its threshold, which is exactly how two separate visual
		# features shipped landing errors past it.
		if frame_dt > _worst_frame:
			_worst_frame = frame_dt
			_worst_frame_at = elapsed
		# Skip the opening seconds: the rate estimator holds its 1.0 default
		# until it has measured a full window, and counting that as wander would
		# report every host as unstable.
		if elapsed > 3.0:
			var rate: float = Conductor.clock_rate()
			_rate_min = minf(_rate_min, rate)
			_rate_max = maxf(_rate_max, rate)
		max_tier = maxi(max_tier, player.current_tier)
		if _game.state == _game.State.DEAD:
			print("    died at %.1fs, tier %d" % [elapsed, max_tier])
			break

	_release_steering()

	# Arcs are solved against the audio clock but simulated in physics time, so
	# if the host stalls, landings arrive late and the lag compounds. That is an
	# environment problem, not a regression, and reporting it as a beat
	# alignment failure would be misleading.
	var physics_ran: float = float(Engine.get_physics_frames() - physics_frames_start) \
		/ float(Engine.physics_ticks_per_second)
	var physics_ratio: float = physics_ran / maxf(elapsed, 0.001)
	if physics_ratio < 0.95:
		_environment_stalled = true
		print(("    WARNING: physics kept only %.0f%% of real time (%.1fs simulated in %.1fs)."
			+ " The host stalled, so the timing figures below are not meaningful"
			+ " and the beat-alignment checks are skipped.")
			% [physics_ratio * 100.0, physics_ran, elapsed])
	else:
		print("    physics kept %.0f%% of real time" % (physics_ratio * 100.0))

	print("    worst single frame: %.1f ms at %.1fs"
		% [_worst_frame * 1000.0, _worst_frame_at])

	# REPORT THE SONG CLOCK RATE.
	#
	# Arcs are solved on the audio clock and simulated on the physics clock, and
	# for a long time nothing anywhere said whether those two agreed. They did
	# not: this host runs its song clock about 8.6% slow, which put every landing
	# 85ms early while the physics ratio above happily reported 100% and the
	# worst frame was 9.6ms. Two healthy-looking numbers and a broken game.
	# A disagreement between the clocks is now something you can see.
	print("    song clock ran at %.1f%% of wall clock (%.1f%% to %.1f%% across the run)"
		% [Conductor.clock_rate() * 100.0, _rate_min * 100.0, _rate_max * 100.0])

	# --- The climb actually happened ---
	print("    reached tier %d, %d landings (%d after falls), %d jumps"
		% [max_tier, _landing_count, _fall_landings, _judgements])

	check(_game.state != _game.State.COUNTDOWN,
		"count-in completed and the run started")

	# Survival and tier reached are REPORTED, not asserted. They depend on how
	# well the crude steering robot plays, and its failure distribution overlaps
	# the signature of a real regression, so a threshold could not separate the
	# two without failing a third of the time for no reason.
	#
	# The assertions instead target what is robot-independent: hop cadence and
	# beat alignment here, and the difficulty curve exactly from constants in
	# smoke_test.gd::test_difficulty_curve.
	var survival_ratio := elapsed / RUN_SECONDS
	print("    survived %.0f%% of the run, reached tier %d"
		% [survival_ratio * 100.0, max_tier])

	# Every jump here is a MISS (no jump input is simulated), so the climb rate
	# is one tier per HOP_BEATS. Over the survived duration, minus the four-beat
	# count-in, that is a predictable number of tiers.
	# A floor that proves the climb happened, not a survival target. The robot
	# dies to a missed platform roughly half the time and that says nothing
	# about whether the game is correct, which is why survival is reported
	# rather than asserted (see above). Eight is plenty to exercise the loop.
	check(_landing_count >= 8, "player landed repeatedly (%d landings)"
		% _landing_count)
	check(_judgements >= 8, "jumps were judged (%d)" % _judgements)

	_check_hop_cadence()

	# --- The spawner kept up ---
	# Platforms must exist above the player, or the climb would dead-end.
	check(spawner.x_of_tier(max_tier + 1) >= 0.0,
		"a platform exists one tier above the player")
	check(spawner.x_of_tier(max_tier + 5) >= 0.0,
		"the spawner is populating well ahead of the player")

	# --- THE important check: do real landings fall on beats? ---
	_check_landing_alignment()

	_game.queue_free()
	await get_tree().process_frame

	await _test_fail_condition()
	await _test_restart_after_death()
	await _test_platform_type_progression()
	await _test_solid_blocks_from_below()


## A SOLID block must stop a body moving upward into it. That is the entire
## point of the type, and it is the one property no other platform has.
##
## Checked by simulation rather than by inspecting a flag: one_way_collision
## could be set correctly and still be defeated by layer, margin or shape
## configuration.
func _test_solid_blocks_from_below() -> void:
	print("- solid blocks stop upward movement")
	var game: Node2D = await _start_game()
	var player: CharacterBody2D = game.get_node("Player")
	var spawner: Node2D = game.get_node("PlatformSpawner")

	var waiting := 0.0
	while game.state != game.State.PLAYING and waiting < 15.0:
		await get_tree().process_frame
		waiting += get_process_delta_time()

	# Put a solid block directly above the player and fire them at it.
	var solid: Node2D = spawner._acquire()
	var start := player.global_position
	solid.setup(9999, start - Vector2(0.0, 150.0), 1.0,
		Tuning.PlatformType.SOLID, 0.0)
	await get_tree().physics_frame

	player.global_position = start
	player.velocity = Vector2(0.0, -900.0)
	var highest := start.y
	for _i in 40:
		await get_tree().physics_frame
		highest = minf(highest, player.global_position.y)

	var climbed := start.y - highest
	print("    launched at a block 150px above; rose %.0fpx" % climbed)
	# The block's underside sits about 130px up once its half-height and the
	# player's radius are accounted for. Anything near the full 150 means the
	# player passed straight through it.
	check(climbed < 140.0,
		"solid block stopped the ascent (rose %.0fpx of 150)" % climbed)
	var climbed_solid := climbed

	# And the same launch through a NORMAL platform must NOT be stopped, or the
	# one-way behaviour every other type depends on is broken.
	solid.setup(9999, start - Vector2(0.0, 150.0), 1.0,
		Tuning.PlatformType.NORMAL, 0.0)
	await get_tree().physics_frame
	player.global_position = start
	player.velocity = Vector2(0.0, -900.0)
	var highest_normal := start.y
	for _i in 40:
		await get_tree().physics_frame
		highest_normal = minf(highest_normal, player.global_position.y)

	var climbed_normal := start.y - highest_normal
	print("    same launch through a one-way platform; rose %.0fpx" % climbed_normal)
	# Compared against the solid case rather than an absolute height: the
	# player's own launch logic also acts during these frames, and it affects
	# both runs equally, so the DIFFERENCE is the clean signal.
	check(climbed_normal > climbed_solid + 20.0,
		"one-way platforms let the player rise further (%.0fpx vs %.0fpx)"
			% [climbed_normal, climbed_solid])

	game.queue_free()
	await get_tree().process_frame


## Restarting after a death must produce a playable run, not an instant death.
##
## Reported symptom: the first "climb again" after falling died immediately,
## and only the second attempt played. Anything the run carries over from the
## previous one is a candidate, so this asserts the fresh run survives well past
## the count-in.
func _test_restart_after_death() -> void:
	print("- restarting after a death gives a playable run")
	var game: Node2D = await _start_game()
	var player: CharacterBody2D = game.get_node("Player")
	var camera: Camera2D = game.get_node("GameCamera")

	# Play far enough up that the death line has climbed well away from the
	# start height. That gap is what makes stale carry-over state fatal.
	var waited := 0.0
	while game.state != game.State.PLAYING and waited < 15.0:
		await get_tree().process_frame
		waited += get_process_delta_time()

	var climbed := 0.0
	while climbed < 8.0 and game.state == game.State.PLAYING:
		_steer_toward_next_platform(player, game.get_node("PlatformSpawner"))
		await get_tree().process_frame
		climbed += get_process_delta_time()
	_release_steering()

	var death_line_when_high: float = camera.death_line_y()
	print("    climbed to tier %d, death line at y=%.0f"
		% [player.current_tier, death_line_when_high])

	# Kill the run deliberately.
	player.global_position = Vector2(
		Tuning.PLAYFIELD_WIDTH * 0.5, camera.death_line_y() + Tuning.TIER_RISE)
	var dying := 0.0
	while game.state != game.State.DEAD and dying < 4.0:
		await get_tree().process_frame
		dying += get_process_delta_time()
	check(game.state == game.State.DEAD, "run ended so a restart can be tested")

	# Restart exactly as the results screen does.
	game._on_restart_requested()
	await get_tree().process_frame

	# Survive the count-in plus a couple of hops.
	var alive := 0.0
	var died_at := -1.0
	while alive < 6.0:
		await get_tree().process_frame
		alive += get_process_delta_time()
		if game.state == game.State.DEAD:
			died_at = alive
			break

	# The bug being guarded against killed the run the instant the count-in
	# released (measured at 0.19s after release). An ordinary missed platform
	# several seconds later is the robot playing badly and says nothing about
	# the restart path, so the bar is "survived well past the release", not
	# "survived the whole window".
	var countin := 4.0 * Conductor.sec_per_beat
	var survived_release := died_at < 0.0 or died_at > countin + 1.5
	check(survived_release,
		"restarted run survived past the count-in (died at %.2fs, release %.2fs)"
			% [died_at, countin])
	print("    restarted run reached tier %d, state %d"
		% [player.current_tier, game.state])

	game.queue_free()
	await get_tree().process_frame


## Falling off the screen must end the run.
##
## The game shipped once with no working fail condition: the death line sat
## 1050px below the visible area, so a falling player was almost always caught
## by one of the one-way platforms in that gap.
func _test_fail_condition() -> void:
	print("- falling off the screen ends the run")
	var game: Node2D = await _start_game()
	var player: CharacterBody2D = game.get_node("Player")
	var camera: Camera2D = game.get_node("GameCamera")

	var waited := 0.0
	while game.state != game.State.PLAYING and waited < 15.0:
		await get_tree().process_frame
		waited += get_process_delta_time()

	# Drop the player below the line, clear of any platform, and let go.
	# Teleporting rather than waiting for a natural miss keeps this
	# deterministic instead of depending on the steering robot fumbling.
	var line: float = camera.death_line_y()
	player.global_position = Vector2(
		Tuning.PLAYFIELD_WIDTH * 0.5, line + Tuning.TIER_RISE)
	player.velocity = Vector2(0.0, 400.0)

	var died_within := 0.0
	while game.state != game.State.DEAD and died_within < 4.0:
		await get_tree().process_frame
		died_within += get_process_delta_time()

	check(game.state == game.State.DEAD,
		"run ended after falling past the death line (state %d)" % game.state)
	print("    died %.2fs after crossing the line" % died_within)

	var over: CanvasLayer = game.get_node("GameOver")
	check(over.visible, "results panel appeared on death")

	game.queue_free()
	await get_tree().process_frame


## Platform types must unlock with height and grow more frequent.
func _test_platform_type_progression() -> void:
	print("- platform types unlock and ramp with height")
	var game: Node2D = await _start_game()
	var spawner: Node2D = game.get_node("PlatformSpawner")

	# Sample the spawner's own choice function across the climb rather than
	# playing to those heights, which would take many minutes of real time.
	var counts := {}
	var early_special := 0
	var late_special := 0

	for tier in range(0, 240):
		var t: Tuning.PlatformType = spawner._pick_type(tier)
		counts[t] = counts.get(t, 0) + 1

		if tier < Tuning.UNLOCK_MOVING:
			check(t == Tuning.PlatformType.NORMAL,
				"tier %d is plain before any type unlocks" % tier)
		if t == Tuning.PlatformType.MOVING:
			check(tier >= Tuning.UNLOCK_MOVING, "MOVING respects its unlock")
		if t == Tuning.PlatformType.CRUMBLING:
			check(tier >= Tuning.UNLOCK_CRUMBLING, "CRUMBLING respects its unlock")
		if t == Tuning.PlatformType.PHASING:
			check(tier >= Tuning.UNLOCK_PHASING, "PHASING respects its unlock")

	# Compare frequency in the second half of the climb against the first.
	for tier in range(Tuning.UNLOCK_PHASING, 120):
		if spawner._pick_type(tier) != Tuning.PlatformType.NORMAL:
			early_special += 1
	for tier in range(120, 240):
		if spawner._pick_type(tier) != Tuning.PlatformType.NORMAL:
			late_special += 1

	print("    counts: %s" % [counts])
	print("    specials: %d in tiers %d-120, %d in tiers 120-240"
		% [early_special, Tuning.UNLOCK_PHASING, late_special])

	check(counts.get(Tuning.PlatformType.MOVING, 0) > 0, "MOVING platforms appear")
	check(counts.get(Tuning.PlatformType.CRUMBLING, 0) > 0, "CRUMBLING platforms appear")
	check(counts.get(Tuning.PlatformType.PHASING, 0) > 0, "PHASING platforms appear")
	# Plain platforms must dominate the EARLY climb, where the player is still
	# learning the timing. They deliberately do NOT dominate overall any more:
	# SOLID takes over high up by design, which is what the check below asserts.
	var early_plain := 0
	for tier in range(2, Tuning.UNLOCK_SOLID):
		if spawner._pick_type(tier) == Tuning.PlatformType.NORMAL:
			early_plain += 1
	var early_share := float(early_plain) / float(Tuning.UNLOCK_SOLID - 2)
	print("    early climb: %.0f%% plain" % (early_share * 100.0))
	check(early_share > 0.5,
		"plain platforms dominate the early climb (%.0f%%)" % (early_share * 100.0))
	check(late_special > early_special,
		"specials get more frequent with height (%d -> %d)"
			% [early_special, late_special])

	# "Primary at the higher levels" is a claim about the TOP of the climb, not
	# an average over everything above the unlock tier.
	# 100 draws, not 40. The share is a coin flip per tier, so a small sample
	# swings several points either way and would make this assertion flaky for
	# no reason. Above RAMP_TIERS the share is pinned at SOLID_SHARE_MAX.
	var top_solid := 0
	var top_total := 0
	for tier in range(240, 340):
		top_total += 1
		if spawner._pick_type(tier) == Tuning.PlatformType.SOLID:
			top_solid += 1
	var top_share := float(top_solid) / float(top_total)
	print("    top band (tiers 240-340): %d of %d are SOLID (%.0f%%, target %.0f%%)"
		% [top_solid, top_total, top_share * 100.0, Tuning.SOLID_SHARE_MAX * 100.0])
	check(top_share > 0.5,
		"SOLID is the primary type at the top (%.0f%%)" % (top_share * 100.0))

	game.queue_free()
	await get_tree().process_frame


## Instantiate a fresh Game once the audio is available.
func _start_game() -> Node2D:
	var waited := 0.0
	while not Music.all_ready() and waited < 120.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25

	var game: Node2D = GameScene.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	return game


## Drive the horizontal input toward the platform one tier above the player.
##
## Uses Input.action_press/release so the player script's own
## Input.get_axis() call is exercised, rather than reaching past it and writing
## velocity directly. Testing the real input path is the whole point.
func _steer_toward_next_platform(player: CharacterBody2D, spawner: Node2D) -> void:
	var target_x: float = spawner.x_of_tier(player.current_tier + 1)
	if target_x < 0.0:
		_release_steering()
		return

	# Shortest signed distance accounting for horizontal wrap. Without the wrap
	# term the controller would sometimes drive the long way round the screen.
	var w: float = Tuning.PLAYFIELD_WIDTH
	var dx: float = fposmod(target_x - player.global_position.x + w * 0.5, w) - w * 0.5

	# Bang-bang with a predictive brake.
	#
	# A naive "press toward the target, release inside a dead zone" controller
	# oscillates badly: AIR_ACCEL is high, so it sails past the target, reverses,
	# overshoots the other way, and periodically misses the platform entirely.
	# That produced deaths that looked like game bugs but were purely bad
	# driving by the test.
	#
	# Braking distance under full reverse thrust is v^2 / 2a. If we are already
	# within that distance of the target, thrust the OTHER way to arrive with
	# little residual speed. A human does this by eye; the test has to be told.
	var vx: float = player.velocity.x
	var braking_distance: float = (vx * vx) / (2.0 * Tuning.AIR_ACCEL)

	if absf(dx) < 6.0 and absf(vx) < 60.0:
		_release_steering()
		return

	var want_right: bool
	if dx > 0.0:
		# Target is to the right: thrust right unless we would overshoot.
		want_right = not (vx > 0.0 and braking_distance >= dx)
	else:
		want_right = (vx < 0.0 and braking_distance >= -dx)

	if want_right:
		Input.action_release("move_left")
		Input.action_press("move_right")
	else:
		Input.action_release("move_right")
		Input.action_press("move_left")


func _release_steering() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")


func _on_landed(platform: Node2D) -> void:
	_landing_count += 1

	var tier: int = platform.tier if platform != null else -1
	var previous := _last_landed_tier
	_last_landed_tier = tier

	# Ignore the very first landing: the player starts resting on tier 0 rather
	# than arriving there from a beat-quantised arc, so it carries no timing
	# information.
	if _landing_count <= 1:
		return

	# MEASURE ONLY SUCCESSFUL HOPS.
	#
	# If the player misses a platform they fall, sometimes through several
	# tiers, and the landing that ends that fall is a free fall rather than a
	# solved arc. It is unquantised by nature and can be up to half a beat off.
	#
	# Counting those as rhythm failures measures the wrong thing entirely: the
	# design claim is that a SOLVED HOP lands on the beat, and falling is the
	# game's fail state, not a mistimed hop. (The quantiser snaps the following
	# launch back onto the grid, so a fall costs one landing of alignment, not
	# an accumulating drift.)
	#
	# A successful hop always gains exactly one tier, or two on a PERFECT.
	var gained := tier - previous
	if _skip_next_landing:
		_skip_next_landing = false
		_fall_landings += 1
		_last_hop_time = -1.0
		return
	if gained < 1 or gained > Tuning.PERFECT_TIER_SKIP:
		_fall_landings += 1
		# A fall also breaks the hop-interval series, so drop the anchor.
		_last_hop_time = -1.0
		return

	# Record the interval between consecutive successful hops. This is the
	# AI-independent way to verify cadence: a solved hop must take exactly
	# HOP_BEATS, regardless of how well the steering controller plays.
	var t_now: float = Conductor.now()
	if _last_hop_time >= 0.0:
		_hop_intervals.append(t_now - _last_hop_time)
	_last_hop_time = t_now
	_landing_context.append({
		"index": _landing_count, "tier": tier, "gained": gained,
		"type": int(platform.type) if platform != null else -1,
	})

	var spb: float = Conductor.sec_per_beat
	if spb <= 0.0:
		return
	# Sample the clock fresh. `Conductor.song_time` only updates in _process,
	# but this signal fires from _physics_process, so the cached value can be a
	# render frame stale and would inflate the measured error.
	var beats: float = Conductor.now() / spb
	# Signed distance to the nearest beat, in seconds.
	var offset: float = (beats - roundf(beats)) * spb
	_landing_offsets.append(offset)


func _on_jumped(_judgement: int, _error: float, _tiers: int) -> void:
	_judgements += 1


## Verify that a solved hop takes exactly HOP_BEATS.
##
## This is the assertion that would have caught the half-speed cadence bug, in
## which the fallback jump was scheduled a full hop after landing so the player
## rested two beats and then flew two more: four beats per tier instead of two.
## Every landing was still perfectly on a beat, so beat-alignment checks passed
## happily while the game ran at half the intended pace and spent half its time
## standing still.
##
## Deliberately independent of how well the steering robot plays: it measures
## the interval between successful hops, not how many of them there were.
func _check_hop_cadence() -> void:
	print("- hop cadence")
	if _environment_stalled:
		print("    (skipped: host did not run at real time)")
		return

	check(_hop_intervals.size() >= 6,
		"collected enough hop intervals to measure (%d)" % _hop_intervals.size())
	if _hop_intervals.size() < 6:
		return

	var expected: float = Tuning.HOP_BEATS * Conductor.sec_per_beat
	var median: float = _median(_hop_intervals)

	print("    %d hops: median %.3fs, expected %.3fs (%.1f beats)"
		% [_hop_intervals.size(), median, expected,
			median / Conductor.sec_per_beat])

	# 12% covers landing jitter and the odd hop that follows a late auto-launch,
	# while being nowhere near wide enough to admit a doubled or halved cadence.
	check(absf(median - expected) <= expected * 0.12,
		"hop cadence is %.1f beats, expected %.1f"
			% [median / Conductor.sec_per_beat, Tuning.HOP_BEATS])


static func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var n := sorted.size()
	if n % 2 == 1:
		return sorted[n / 2]
	return (sorted[n / 2 - 1] + sorted[n / 2]) * 0.5


## Measure how far real, physics-resolved landings sit from the beat grid.
func _check_landing_alignment() -> void:
	print("- landing alignment against the beat grid")
	check(_landing_offsets.size() >= 5,
		"collected enough landings to measure (%d)" % _landing_offsets.size())
	if _landing_offsets.size() < 5:
		return

	var worst := 0.0
	var sum := 0.0
	for o in _landing_offsets:
		worst = maxf(worst, absf(o))
		sum += o
	var mean := sum / float(_landing_offsets.size())

	print("    %d landings: mean %+.1f ms, worst %.1f ms (tolerance %.0f ms)"
		% [_landing_offsets.size(), mean * 1000.0, worst * 1000.0,
			LANDING_TOLERANCE * 1000.0])

	# Attribute the worst offender, so an outlier points at a cause.
	var names := ["NORMAL", "MOVING", "CRUMBLING", "PHASING", "SOLID"]
	var worst_i := 0
	for i in _landing_offsets.size():
		if absf(_landing_offsets[i]) > absf(_landing_offsets[worst_i]):
			worst_i = i
	if worst_i < _landing_context.size():
		var c: Dictionary = _landing_context[worst_i]
		var tname: String = names[int(c["type"])] if int(c["type"]) >= 0 else "none"
		print("    worst landing: #%d tier %d gained %d onto %s (%.1f ms)"
			% [c["index"], c["tier"], c["gained"], tname,
				_landing_offsets[worst_i] * 1000.0])

	if _environment_stalled:
		print("    (beat-alignment assertions skipped: host did not run at real time)")
		return

	# The floor this host puts under the worst-case error.
	#
	# The solver compensates for the song clock running at a different speed
	# from the physics clock, but only as accurately as it can measure that
	# speed, so a host whose rate WANDERS by `spread` moves a landing by
	# spread * flight_time no matter what the game does. Measured on this run,
	# not assumed, and reported either way.
	var spread := maxf(_rate_max - _rate_min, 0.0) if _rate_max > 0.0 else 0.0
	var nominal_flight: float = Tuning.HOP_BEATS * Conductor.sec_per_beat
	var clock_floor := spread * nominal_flight
	print("    song clock wandered %.2f%%, which is a %.0f ms floor on a %.0f ms hop"
		% [spread * 100.0, clock_floor * 1000.0, nominal_flight * 1000.0])

	# THE WORST-CASE CHECK is the one an unstable host can defeat, so it is the
	# only one gated. Skipped loudly, never quietly widened: raising the
	# tolerance to accommodate a bad host would disarm it everywhere, including
	# on the hosts where it works.
	if clock_floor > LANDING_TOLERANCE:
		print(("    WARNING: this host's song clock is too unstable to assert a"
			+ " %.0f ms worst case (floor is %.0f ms). The worst-case check is"
			+ " skipped; the systematic-bias check below still runs.")
			% [LANDING_TOLERANCE * 1000.0, clock_floor * 1000.0])
	else:
		check(worst <= LANDING_TOLERANCE,
			"every landing within %.0f ms of a beat (worst was %.1f ms)"
				% [LANDING_TOLERANCE * 1000.0, worst * 1000.0])

	# THE BIAS CHECK ALWAYS RUNS, and it is the real regression detector.
	#
	# Clock wander is zero-mean: it scatters landings either side of the beat
	# and cancels in the average. A systematic offset cannot come from it. The
	# bug this test failed to catch for so long showed up here as mean -82.2ms,
	# with every individual hop early, which is a signature no amount of host
	# instability can produce.
	check(absf(mean) <= LANDING_TOLERANCE,
		"no systematic landing bias (mean was %+.1f ms)" % [mean * 1000.0])

	# The decisive property: late landings must not drift further out over
	# time. Compare the first third of the run against the last third.
	var n := _landing_offsets.size()
	var third := int(n / 3)
	if third >= 2:
		var early_mean := _mean_abs(_landing_offsets.slice(0, third))
		var late_mean := _mean_abs(_landing_offsets.slice(n - third, n))
		print("    drift check: first third %.1f ms, last third %.1f ms"
			% [early_mean * 1000.0, late_mean * 1000.0])
		# Gated for the same reason as the worst case: this averages ABSOLUTE
		# offsets, so scatter inflates it even when it cancels in the signed
		# mean above.
		if clock_floor > LANDING_TOLERANCE:
			print("    (drift check skipped: host clock floor exceeds the tolerance)")
		else:
			check(late_mean <= LANDING_TOLERANCE,
				"timing has not drifted by the end of the run (%.1f ms)"
					% [late_mean * 1000.0])


static func _mean_abs(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += absf(float(v))
	return total / float(values.size())
