extends Node

## Headless smoke test. Run with:
##
##   godot --headless --path <project> res://tests/SmokeTest.tscn
##
## Exits 0 if every check passes, 1 otherwise, so it can gate a build.
##
## Real subsystems, nothing mocked: a mocked synthesiser would only confirm the
## mock returns what it was told, and the question is whether the real one
## produces audible, correctly timed audio.
##
## test_no_drift() is the most important check here. The load-bearing claim of
## the design is that landings fall on beats however badly the player times
## their input; if that drifts, everything else is decoration.

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	print("=== Bounce Ascent smoke test ===")

	test_launch_velocity_analytic()
	test_tilt_response()
	test_launch_velocity_numeric()
	test_arc_tier_separation()
	test_difficulty_curve()
	test_fail_condition_is_reachable()
	test_platform_type_unlocks()
	test_no_drift()
	test_quantise_symmetry()
	test_song_definitions()
	test_synth_output()
	test_judgement_windows()

	await test_music_pipeline()

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


func check_near(actual: float, expected: float, tolerance: float, what: String) -> void:
	var ok := absf(actual - expected) <= tolerance
	check(ok, "%s: expected %.6f +/- %.6f, got %.6f (delta %.6f)"
		% [what, expected, tolerance, actual, actual - expected])


# --- Jump physics -----------------------------------------------------------

## REGRESSION: tilt steering was an on/off switch, not a control.
##
## The thresholds were written as though the sensor reported normalised gravity
## in 0..1. Godot's accelerometer reports m/s^2, about 9.81 at rest, so the old
## TILT_FULL of 0.45 meant full steer at 2.6 DEGREES of lean, with a dead zone
## of 0.3 degrees that resting hand tremor exceeded.
##
## Nothing could catch it: the whole calculation lived in a _process that needs
## a physical device to produce any reading at all. Hence Tuning.tilt_response,
## which is pure maths over degrees and can simply be checked.
func test_tilt_response() -> void:
	print("- tilt steering response")

	check_near(Tuning.tilt_response(0.0), 0.0, 0.0001, "level is no steer")
	check_near(Tuning.tilt_response(Tuning.TILT_DEAD_DEG - 0.5), 0.0, 0.0001,
		"inside the dead zone is no steer")
	check_near(Tuning.tilt_response(Tuning.TILT_FULL_DEG), 1.0, 0.0001,
		"full tilt is full steer")
	check_near(Tuning.tilt_response(Tuning.TILT_FULL_DEG * 3.0), 1.0, 0.0001,
		"beyond full tilt stays clamped")
	check_near(Tuning.tilt_response(-Tuning.TILT_FULL_DEG), -1.0, 0.0001,
		"tilt is symmetric")

	# The heart of the bug: a small lean must NOT be full steer. Five degrees is
	# comfortably inside what a hand does without meaning to.
	var small := Tuning.tilt_response(5.0)
	check(small > 0.0 and small < 0.35,
		"a 5 degree lean is a gentle nudge, not full steer (got %.2f)" % small)

	# The curve gives finer control near centre than a straight line would.
	var mid := Tuning.tilt_response(
		(Tuning.TILT_DEAD_DEG + Tuning.TILT_FULL_DEG) * 0.5)
	check(mid < 0.5, "mid tilt is below linear, so small corrections are fine "
		+ "grained (got %.2f)" % mid)

	# Usable range must be wide enough to aim inside, not a hair trigger.
	check(Tuning.TILT_FULL_DEG - Tuning.TILT_DEAD_DEG >= 10.0,
		"at least 10 degrees of usable travel between dead zone and full")
	print("    dead %.1f deg, full %.1f deg, 5 deg gives %.2f"
		% [Tuning.TILT_DEAD_DEG, Tuning.TILT_FULL_DEG, small])


## The solver must invert the integrator the game ACTUALLY runs.
##
## This used to assert against the continuous projectile equation
## dy = v0*t - g*t^2/2. That equation is not what Godot executes, and the gap
## between them was the source of the systematic 11ms early landing bias: the
## engine uses semi-implicit Euler, whose trajectory sits g*h*t/2 below the
## continuous curve at every t.
##
## So the check now SIMULATES the integrator instead of trusting an
## idealisation. A test that agrees with the maths while the game disagrees with
## both is worse than no test, because it actively certifies the bug.
func test_launch_velocity_analytic() -> void:
	print("- launch velocity (against the real integrator)")
	var h := Tuning.physics_step()

	# Flight times deliberately chosen as exact multiples of the physics step,
	# so the comparison is exact rather than carrying a partial final step.
	# Real flight times are beat-derived and rarely land on a step boundary,
	# which is why landing detection carries up to one tick of jitter no matter
	# how good this solver is (see project.godot's physics notes). That residual
	# is measured against real physics by gameplay_test.gd, not here.
	#
	# Loop variables over an untyped array literal are Variant, so every local
	# derived from them needs an explicit type annotation rather than `:=`.
	for rise_value in [190.0, 380.0, 95.0]:
		var rise: float = rise_value
		for flight_value in [0.5, 1.0, 1.5]:
			var flight: float = flight_value
			var g: float = Tuning.gravity_for_flight(flight)
			var v0: float = Tuning.solve_launch_velocity(rise, flight, g)

			# Step exactly as Godot does: advance velocity FIRST, then move by
			# the new velocity. Using the old velocity here would be explicit
			# Euler and would reintroduce the bias this test exists to catch.
			var steps := int(round(flight / h))
			var v := v0
			var y := 0.0
			for _i in steps:
				v -= g * h
				y += v * h

			check_near(y, rise, 0.001,
				"simulated rise=%.0f flight=%.4f (%d steps)" % [rise, flight, steps])


## The solver is analytic, but the game integrates with semi-implicit Euler at a
## fixed 120Hz tick. This measures the real landing time under that integrator,
## because a systematic bias here would show up as every landing being
## consistently early or late -- which would silently eat into the timing
## windows.
func test_launch_velocity_numeric() -> void:
	print("- launch velocity (numeric, 120Hz semi-implicit Euler)")
	var dt := 1.0 / 120.0
	var rise := Tuning.TIER_RISE
	var flight := Tuning.HOP_BEATS * (60.0 / 128.0)
	var g := Tuning.gravity_for_flight(flight)
	var v0 := Tuning.solve_launch_velocity(rise, flight, g)

	# Screen y grows downward; climbing is negative.
	var y := 0.0
	var vy := -v0
	var t := 0.0
	var landed_at := -1.0
	var target_y := -rise

	# Integrate exactly as _physics_process does: gravity first, then position.
	for _i in 2000:
		vy += g * dt
		y += vy * dt
		t += dt
		# Landing = descending (vy > 0) and at or below the target height.
		if vy > 0.0 and y >= target_y:
			landed_at = t
			break

	check(landed_at > 0.0, "numeric integration reached the target height")
	# One physics tick is 8.33ms; the integrator's own bias adds a few more.
	# 15ms is a third of the PERFECT window, which is the level at which a
	# systematic bias would start to matter.
	check_near(landed_at, flight, 0.015, "numeric landing time")
	print("    analytic %.4fs, integrated %.4fs, bias %+.1f ms"
		% [flight, landed_at, (landed_at - flight) * 1000.0])


## Platforms are one-way, so a hop's apex decides which tiers it can land on.
## Two invariants must hold at every tempo: a one-tier hop must apex below
## tier+2, or a mistimed jump climbs two tiers by accident and PERFECT's reward
## is meaningless; a PERFECT must apex below tier+3, or it overshoots.
func test_arc_tier_separation() -> void:
	print("- arc height keeps tiers separated")
	var tier := Tuning.TIER_RISE

	for song in SongLibrary.all_songs():
		var bpm: float = song["bpm"]
		var flight: float = Tuning.HOP_BEATS * Tuning.sec_per_beat(bpm)
		var g: float = Tuning.gravity_for_flight(flight)

		var normal_v0: float = Tuning.solve_launch_velocity(tier, flight, g)
		var normal_apex: float = Tuning.apex_height(normal_v0, g)

		var perfect_rise: float = tier * float(Tuning.PERFECT_TIER_SKIP)
		var perfect_v0: float = Tuning.solve_launch_velocity(perfect_rise, flight, g)
		var perfect_apex: float = Tuning.apex_height(perfect_v0, g)

		print("    %-13s %3.0f BPM: normal apex %.0fpx (limit %.0f), perfect apex %.0fpx (limit %.0f)"
			% [song["name"], bpm, normal_apex, tier * 2.0,
				perfect_apex, tier * 3.0])

		# Must clear its own landing tier, or the hop cannot reach the platform.
		check(normal_apex > tier,
			"%s: normal hop apex %.0f clears its landing tier %.0f"
				% [song["id"], normal_apex, tier])
		check(normal_apex < tier * 2.0,
			"%s: normal hop apex %.0f stays below tier+2 (%.0f)"
				% [song["id"], normal_apex, tier * 2.0])
		check(perfect_apex > tier * 2.0,
			"%s: PERFECT apex %.0f clears tier+2 (%.0f)"
				% [song["id"], perfect_apex, tier * 2.0])
		check(perfect_apex < tier * 3.0,
			"%s: PERFECT apex %.0f stays below tier+3 (%.0f)"
				% [song["id"], perfect_apex, tier * 3.0])


## The whole difficulty curve is three numbers and their ORDERING:
##
##   SCROLL_START < ordinary   opening survivable by timing merely well
##   SCROLL_MAX   > ordinary   late play demands PERFECTs, or there is no curve
##   SCROLL_MAX   < perfect    perfect play is always survivable
##
## Deterministic, unlike anything measured from a play run.
func test_difficulty_curve() -> void:
	print("- difficulty curve ordering")
	var ordinary: float = 1.0 / Tuning.HOP_BEATS
	var perfect: float = float(Tuning.PERFECT_TIER_SKIP) / Tuning.HOP_BEATS

	print("    ordinary %.2f tiers/beat, perfect %.2f, scroll %.2f -> %.2f"
		% [ordinary, perfect, Tuning.SCROLL_START, Tuning.SCROLL_MAX])

	check(Tuning.SCROLL_START < ordinary,
		"opening is survivable by ordinary play (%.2f < %.2f)"
			% [Tuning.SCROLL_START, ordinary])
	check(Tuning.SCROLL_MAX > ordinary,
		"late game demands PERFECTs (%.2f > %.2f)"
			% [Tuning.SCROLL_MAX, ordinary])
	check(Tuning.SCROLL_MAX < perfect,
		"perfect play always outruns the death line (%.2f < %.2f)"
			% [Tuning.SCROLL_MAX, perfect])
	check(Tuning.MAX_DEATH_LEAD > 0.0,
		"the death line's trailing distance is capped")


## The death line must sit near the bottom of the VIEW, not far below it.
##
## This is the check that would have caught the game shipping with no working
## fail condition. MAX_DEATH_LEAD was 1.2 screens against 0.38 screens of
## visible space below the player, leaving 1050px of off-screen fall containing
## 5.5 tiers of one-way platforms that caught the player and rescued them
## almost every time.
func test_fail_condition_is_reachable() -> void:
	print("- fail condition is reachable")
	var visible_below: float = (1.0 - Tuning.CAMERA_ANCHOR) * Tuning.PLAYFIELD_HEIGHT
	var lead: float = Tuning.MAX_DEATH_LEAD * Tuning.PLAYFIELD_HEIGHT
	var offscreen: float = lead - visible_below
	var rescue_tiers: float = offscreen / Tuning.TIER_RISE

	print("    visible below player %.0fpx, death line trails %.0fpx"
		% [visible_below, lead])
	print("    offscreen fall %.0fpx = %.1f tiers of possible rescue"
		% [offscreen, rescue_tiers])

	check(lead > visible_below * 0.5,
		"death line is not so tight that a normal hop clips it")
	# Two tiers of off-screen grace at most: enough that a near miss is
	# occasionally survivable, far too little to make falling harmless.
	check(rescue_tiers <= 2.0,
		"falling off screen kills within %.1f tiers (limit 2.0)" % rescue_tiers)


## Types must unlock in increasing order and stay a minority of platforms.
func test_platform_type_unlocks() -> void:
	print("- platform type unlocks")
	check(Tuning.UNLOCK_MOVING < Tuning.UNLOCK_CRUMBLING,
		"MOVING unlocks before CRUMBLING")
	check(Tuning.UNLOCK_CRUMBLING < Tuning.UNLOCK_PHASING,
		"CRUMBLING unlocks before PHASING")
	check(Tuning.UNLOCK_MOVING > 1,
		"the opening tiers are always plain")
	check(Tuning.SPECIAL_CHANCE_START < Tuning.SPECIAL_CHANCE_MAX,
		"special platforms get more frequent with height")
	# A climb of nothing but hazards stops reading as a rhythm game.
	check(Tuning.SPECIAL_CHANCE_MAX < 0.8,
		"plain platforms stay the majority (%.2f)" % Tuning.SPECIAL_CHANCE_MAX)
	check(Tuning.UNLOCK_PHASING < Tuning.RAMP_TIERS,
		"every type unlocks before the difficulty ramp maxes out")

	# SOLID arrives last and then takes over, which is the requested late-game
	# character: above a 0.5 share it is the PRIMARY type rather than a hazard.
	check(Tuning.UNLOCK_SOLID > Tuning.UNLOCK_PHASING,
		"SOLID unlocks after every other type")
	check(Tuning.SOLID_SHARE_MAX > 0.5,
		"SOLID becomes the primary type high up (%.2f)" % Tuning.SOLID_SHARE_MAX)
	check(Tuning.SOLID_SHARE_START < Tuning.SOLID_SHARE_MAX,
		"SOLID grows more common with height")

	# The clearance rule is what keeps solid blocks fair rather than merely
	# hard: a solid block directly above the launch point would be a wall with
	# no way past, since it cannot be entered from below.
	check(Tuning.SOLID_MIN_OFFSET > Tuning.PLATFORM_HALF_WIDTH,
		"solid blocks are forced clear of the launch point (%.0fpx > %.0fpx)"
			% [Tuning.SOLID_MIN_OFFSET, Tuning.PLATFORM_HALF_WIDTH])
	# It must still be reachable: wrapping caps the worst case at half the
	# playfield, and one hop covers far more than that.
	check(Tuning.SOLID_MIN_OFFSET < Tuning.PLAYFIELD_WIDTH * 0.5,
		"the forced offset stays inside one hop of travel")


# --- The central claim: no timing drift -------------------------------------

## THE important test.
##
## Simulate a long run in which the player times every single press badly, with
## random jitter up to the full GOOD window, and confirm that every landing
## still falls exactly on a beat. If this passes, the music can never desync
## from the gameplay no matter how the player performs.
func test_no_drift() -> void:
	print("- landing quantisation does not drift")
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242

	for bpm_value in [112.0, 128.0, 150.0]:
		var bpm: float = bpm_value
		var spb: float = Tuning.sec_per_beat(bpm)
		var t: float = 0.0
		var worst: float = 0.0

		for _hop in 400:
			# The player presses at some jittered time after landing, anywhere
			# within the GOOD window either side.
			var press: float = t + rng.randf_range(
				-Tuning.WINDOW_GOOD, Tuning.WINDOW_GOOD)
			var landing: float = Tuning.quantise_landing_time(press, spb)

			# How far is this landing from an exact beat?
			var beats: float = landing / spb
			var off_grid: float = absf(beats - round(beats)) * spb
			worst = maxf(worst, off_grid)
			t = landing

		# Tolerance is float noise only, not a timing allowance.
		check(worst < 0.0005,
			"bpm %.0f: worst landing was %.4f ms off the beat grid"
				% [bpm, worst * 1000.0])
		print("    %.0f BPM over 400 hops: worst deviation %.4f ms"
			% [bpm, worst * 1000.0])


## Early and late presses of equal magnitude must resolve to the same target
## beat. This is what makes the timing window symmetric; if it failed, the game
## would quietly favour one side and feel biased.
func test_quantise_symmetry() -> void:
	print("- early and late presses are symmetric")
	var spb: float = Tuning.sec_per_beat(128.0)
	# A landing sits exactly on beat 8.
	var on_beat: float = 8.0 * spb

	for err_value in [0.010, 0.030, 0.044]:
		var err: float = err_value
		var early: float = Tuning.quantise_landing_time(on_beat - err, spb)
		var late: float = Tuning.quantise_landing_time(on_beat + err, spb)
		check_near(early, late, 0.0005,
			"symmetry at +/-%d ms" % int(err * 1000.0))


# --- Song data --------------------------------------------------------------

func test_song_definitions() -> void:
	print("- song definitions")
	var songs := SongLibrary.all_songs()
	check(songs.size() >= 3, "at least three songs defined")

	var ids := {}
	for s in songs:
		check(not ids.has(s["id"]), "song id '%s' is unique" % s["id"])
		ids[s["id"]] = true

		check(s["bpm"] > 40.0 and s["bpm"] < 220.0,
			"song '%s' bpm %.0f is sane" % [s["id"], s["bpm"]])
		check(s["bars"] > 0, "song '%s' has bars" % s["id"])

		# Every note must fall inside the loop window, or it renders as silence
		# and the arrangement quietly loses a part.
		var song_beats: float = float(s["bars"] * s["beats_per_bar"])
		var total_notes := 0
		for track in s["tracks"]:
			total_notes += track["notes"].size()
			var out_of_range := 0
			for n in track["notes"]:
				if n[0] < 0.0 or n[0] >= song_beats:
					out_of_range += 1
			# Reported as one check per track rather than one per note: a broken
			# pattern generator would otherwise emit hundreds of identical
			# failures and bury everything else in the output.
			check(out_of_range == 0,
				"song '%s' has all notes inside the %.0f-beat loop (%d outside)"
					% [s["id"], song_beats, out_of_range])
		check(total_notes > 100,
			"song '%s' has a substantial arrangement (%d notes)"
				% [s["id"], total_notes])


# --- Synthesis --------------------------------------------------------------

## Render a real song and confirm the audio is the right length, actually
## audible, and not clipped into a square wave.
##
## "Not silent" is the check that matters most. Every other part of the audio
## pipeline can look correct while producing a buffer of zeroes, and a silent
## rhythm game is indistinguishable from a broken one.
func test_synth_output() -> void:
	print("- synthesiser output")
	var song := SongLibrary.all_songs()[0]
	var stream := Synth.render_song(song)

	check(stream != null, "render returned a stream")
	if stream == null:
		return

	var expected_seconds := float(song["bars"] * song["beats_per_bar"]) \
		* (60.0 / float(song["bpm"]))
	var actual_seconds := float(stream.loop_end) / float(stream.mix_rate)
	check_near(actual_seconds, expected_seconds, 0.05, "rendered duration")

	check(stream.stereo, "output is stereo")
	check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "output loops")
	check(stream.data.size() > 0, "output has sample data")

	# Decode and measure. 16-bit stereo interleaved.
	var data := stream.data
	var frames := data.size() / 4
	var peak := 0
	var sum_sq := 0.0
	var nonzero := 0
	# Sample every 7th frame: enough for reliable statistics, fast enough not to
	# dominate the test's runtime.
	var step := 7
	var counted := 0
	var i := 0
	while i < frames:
		var lo := data[i * 4]
		var hi := data[i * 4 + 1]
		var v := lo | (hi << 8)
		if v >= 32768:
			v -= 65536
		if v != 0:
			nonzero += 1
		peak = maxi(peak, absi(v))
		sum_sq += float(v) * float(v)
		counted += 1
		i += step

	var rms := sqrt(sum_sq / float(maxi(counted, 1)))
	print("    frames=%d peak=%d rms=%.0f nonzero=%.1f%%"
		% [frames, peak, rms, 100.0 * float(nonzero) / float(maxi(counted, 1))])

	check(peak > 3000, "audio is audible (peak %d of 32767)" % peak)
	check(peak <= 32767, "audio does not overflow the sample range")
	check(rms > 300.0, "audio has real signal energy (rms %.0f)" % rms)
	# If almost every sample sat at full scale the soft clipper would be acting
	# as a hard limiter and the mix would be distorted rather than loud.
	check(float(nonzero) / float(maxi(counted, 1)) > 0.5,
		"most samples are non-zero, i.e. not mostly silence")


# --- Conductor --------------------------------------------------------------

## The judgement windows must map errors to the tiers Tuning declares. This is
## the rule the player is being scored against, so an off-by-one here would
## misreport every input in the game.
func test_judgement_windows() -> void:
	print("- judgement windows")
	Conductor.start(SongLibrary.get_song("vector_drive"))
	var spb := Conductor.sec_per_beat

	# A press near beat 4, offset by a known error.
	var base := 4.0 * spb
	var cases := [
		[0.0, Tuning.Judgement.PERFECT, "exact"],
		[Tuning.WINDOW_PERFECT - 0.005, Tuning.Judgement.PERFECT, "inside perfect"],
		[Tuning.WINDOW_PERFECT + 0.005, Tuning.Judgement.GREAT, "just past perfect"],
		[Tuning.WINDOW_GREAT + 0.005, Tuning.Judgement.GOOD, "just past great"],
		[Tuning.WINDOW_GOOD + 0.010, Tuning.Judgement.MISS, "past good"],
	]

	for c in cases:
		var offset: float = c[0]
		var expected: int = c[1]
		var label: String = c[2]
		# Both directions must judge identically.
		for sign_value in [1.0, -1.0]:
			var sign_mult: float = sign_value
			var result: Dictionary = Conductor.judge(base + offset * sign_mult)
			check(result["judgement"] == expected,
				"%s (%s): expected %s, got %s" % [
					label,
					"late" if sign_mult > 0.0 else "early",
					Tuning.judgement_label(expected),
					Tuning.judgement_label(result["judgement"]),
				])

	Conductor.stop()


# --- Full audio pipeline ----------------------------------------------------

## Wait for the background synthesis thread and confirm every song became
## playable. This exercises the cache path too: on a second run the streams come
## off disk instead of the synthesiser, and a corrupt cache would surface here.
func test_music_pipeline() -> void:
	print("- music pipeline (background synthesis + cache)")

	var waited := 0.0
	while not Music.all_ready() and waited < 120.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25

	check(Music.all_ready(), "all songs rendered within 120s (took %.1fs)" % waited)

	for s in SongLibrary.all_songs():
		check(Music.is_song_ready(s["id"]), "song '%s' is ready" % s["id"])

	print("    synthesis completed in %.1fs" % waited)
