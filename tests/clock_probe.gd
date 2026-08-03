extends Node

## Diagnostic probe for landings that miss their beat with no frame stall.
##
##   godot --headless --path <project> res://tests/ClockProbe.tscn
##
## Always exits 0. This REPORTS, it does not assert: its job is to say which of
## two clocks was wrong, not to gate a build.
##
## THE QUESTION
## ------------
## Roughly one run in six had a landing 124 to 167ms away from its beat against
## a 25ms tolerance, while the worst single frame in the same run was 9.6ms. No
## stall, so the arc was simulated at full speed and still arrived at the wrong
## moment. Something other than lost frames is moving landings.
##
## An arc is SOLVED in audio time and SIMULATED in physics time. Those are two
## different clocks, and only one of them can be at fault:
##
##   * If the arc took the real-time duration it was solved for, the simulation
##     did its job and the AUDIO CLOCK moved underneath it. A clock reading Δ
##     ahead of truth at launch makes flight = target - now come out Δ short, so
##     the player touches down Δ EARLY with every frame on time. That is the
##     exact signature being chased.
##
##   * If the arc took a different real-time duration than it was solved for,
##     the clock is fine and the fault is in the physics or the geometry: a
##     launch from the wrong height, a clamped flight time, a platform met on
##     the way up.
##
## So every hop is recorded twice, in wall-clock microseconds and in song time,
## and the two are compared. The wall clock is the independent reference; it is
## never derived from the audio clock, which is the whole point.

const GameScene: PackedScene = preload("res://scenes/Game.tscn")

## Seconds per run, and how many runs. Several short runs rather than one long
## one: the failure is intermittent at roughly one in six, so the probe needs
## more than one chance to see it.
const RUN_SECONDS: float = 26.0
const RUNS: int = 4

## A landing further than this from its beat is worth a full dump.
const INTERESTING: float = 0.025

var _game: Node2D
var _player: CharacterBody2D

## Per-hop records for the run in progress.
var _hops: Array[Dictionary] = []

var _last_landed_tier: int = -1
var _skip_next_landing: bool = false

# --- Clock divergence -------------------------------------------------------
#
# Sampled every physics frame. The audio clock and the wall clock should
# advance together; where they do not is where a solved arc can be handed a time
# that has not happened yet.

var _prev_audio: float = -1.0
var _prev_usec: int = 0

## Worst single-frame divergence between the two clocks, in seconds, and when.
var _worst_ahead: float = 0.0
var _worst_ahead_at: float = 0.0
var _worst_behind: float = 0.0
var _worst_behind_at: float = 0.0

## How often the audio clock did not move at all across a physics frame, which
## is what the monotonic clamp in Music.get_audio_time produces after an
## over-read: the clock stands still until real time catches up.
var _frozen_frames: int = 0
var _physics_samples: int = 0

var _run_elapsed: float = 0.0

## Range of the song clock rate estimate across a run.
##
## This separates two things that look identical in a landing offset: an
## estimator that is too noisy, and a host clock that genuinely wanders. If the
## spread here is wide, no estimator can hold landings inside the tolerance and
## the honest report is that the environment cannot support the measurement.
var _rate_min: float = 99.0
var _rate_max: float = 0.0


func _ready() -> void:
	print("=== Bounce Ascent clock probe ===")
	print("- comparing SOLVED flight time against ACTUAL wall-clock flight time")
	print("- %d runs of %.0fs" % [RUNS, RUN_SECONDS])
	for run in RUNS:
		await _one_run(run + 1)
	print("---")
	print("probe complete")
	get_tree().quit(0)


func _one_run(index: int) -> void:
	print("\n--- run %d ---" % index)

	var waited := 0.0
	while not Music.all_ready() and waited < 120.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25

	_hops.clear()
	_last_landed_tier = -1
	_skip_next_landing = false
	_prev_audio = -1.0
	_worst_ahead = 0.0
	_worst_behind = 0.0
	_frozen_frames = 0
	_physics_samples = 0
	_run_elapsed = 0.0
	_rate_min = 99.0
	_rate_max = 0.0

	_game = GameScene.instantiate()
	add_child(_game)
	await get_tree().process_frame

	_player = _game.get_node("Player")
	var spawner: Node2D = _game.get_node("PlatformSpawner")
	_player.landed.connect(_on_landed)
	_player.bonked.connect(func(): _skip_next_landing = true)

	set_physics_process(true)

	while _run_elapsed < RUN_SECONDS:
		_steer(spawner)
		await get_tree().process_frame
		_run_elapsed += get_process_delta_time()
		if _game.state == _game.State.DEAD:
			break

	set_physics_process(false)
	_release()
	_report()

	_game.queue_free()
	await get_tree().process_frame


## Sample both clocks at the rate arcs are actually simulated at.
func _physics_process(_delta: float) -> void:
	var now_usec := Time.get_ticks_usec()
	var now_audio := Conductor.now()

	if _prev_audio >= 0.0:
		var d_real := float(now_usec - _prev_usec) / 1_000_000.0
		var d_audio := now_audio - _prev_audio
		# Positive means the song clock ran FASTER than the wall clock over this
		# frame, which is how a solver ends up being handed a time in the future.
		var diff := d_audio - d_real
		if diff > _worst_ahead:
			_worst_ahead = diff
			_worst_ahead_at = _run_elapsed
		if -diff > _worst_behind:
			_worst_behind = -diff
			_worst_behind_at = _run_elapsed
		if d_audio <= 0.0:
			_frozen_frames += 1
		_physics_samples += 1

		# Only once the estimator has a real measurement to report; before that
		# it holds its 1.0 default and would widen the range for no reason.
		if _run_elapsed > 3.0:
			var rate: float = Conductor.clock_rate()
			_rate_min = minf(_rate_min, rate)
			_rate_max = maxf(_rate_max, rate)

	_prev_audio = now_audio
	_prev_usec = now_usec


func _on_landed(platform: Node2D) -> void:
	var tier: int = platform.tier if platform != null else -1
	var previous := _last_landed_tier
	_last_landed_tier = tier

	if previous < 0:
		return
	if _skip_next_landing:
		_skip_next_landing = false
		return

	# Only solved hops carry timing information. A landing that ends a fall is
	# unquantised by nature and says nothing about the solver.
	var gained := tier - previous
	if gained < 1 or gained > Tuning.PERFECT_TIER_SKIP:
		return

	var land_usec := Time.get_ticks_usec()
	var land_audio: float = Conductor.now()
	var spb: float = Conductor.sec_per_beat
	if spb <= 0.0:
		return

	var beats := land_audio / spb
	var offset := (beats - roundf(beats)) * spb

	# THE comparison. Solved is what the arc was asked for; real is what the
	# simulation actually delivered, measured on a clock the audio subsystem
	# cannot touch.
	#
	# Read through explicitly typed locals: these are members the player script
	# declares, but `_player` is held as a CharacterBody2D, so the compiler sees
	# Variant and cannot infer a type for the arithmetic.
	var land_vy: float = _player.last_land_vy
	var land_frames: int = _player.last_land_frames
	var launch_usec: int = _player.last_launch_usec
	var launch_time: float = _player.last_launch_time
	var solved: float = _player.last_flight_solved
	var launch_y: float = _player.last_launch_y
	var rise_solved: float = _player.last_launch_rise

	var real_flight := float(land_usec - launch_usec) / 1_000_000.0
	var audio_flight := land_audio - launch_time

	# Where the platform ACTUALLY is, against where its tier says it should be.
	#
	# Added after two hypotheses for the snag were tested and refuted: a body
	# rising straight up passes cleanly at every speed the game produces (33
	# speeds, 600 to 2200 px/s), and so does a body rising diagonally across the
	# platform's edge (204 launches). Both of those assumed the platform was
	# where its tier put it. This checks that assumption instead of making a
	# third guess about collision behaviour.
	var spawner: Node2D = _game.get_node("PlatformSpawner")
	var platform_y: float = platform.global_position.y if platform != null else 0.0
	var expected_y: float = spawner.tier_y(tier)

	_hops.append({
		"tier": tier,
		"gained": gained,
		"type": int(platform.type) if platform != null else -1,
		"offset": offset,
		"solved": solved,
		"real": real_flight,
		"audio": audio_flight,
		"rise_solved": rise_solved,
		"rise_actual": launch_y - _player.global_position.y,
		"platform_y": platform_y,
		"platform_dy": platform_y - expected_y,
		"land_vy": land_vy,
		"land_frames": land_frames,
		"at": _run_elapsed,
	})


func _report() -> void:
	var names := ["NORMAL", "MOVING", "CRUMBLING", "PHASING", "SOLID"]

	print("    %d solved hops, %d physics samples" % [_hops.size(), _physics_samples])
	print("    clock divergence per frame: worst AHEAD %+.1f ms at %.1fs, worst BEHIND %.1f ms at %.1fs"
		% [_worst_ahead * 1000.0, _worst_ahead_at,
			_worst_behind * 1000.0, _worst_behind_at])
	print("    frames where the song clock did not advance at all: %d of %d (%.0f%%)"
		% [_frozen_frames, _physics_samples,
			100.0 * float(_frozen_frames) / maxf(float(_physics_samples), 1.0)])

	if _rate_max > 0.0:
		# The spread IS the achievable floor: a rate estimate uncertain by this
		# much moves a one second landing by spread * 1000 ms, no matter how the
		# estimator is written.
		var spread := _rate_max - _rate_min
		print("    song clock rate: %.4f to %.4f (spread %.2f%%, floor on a 1s hop %.0f ms)"
			% [_rate_min, _rate_max, spread * 100.0, spread * 1000.0])

	if _hops.is_empty():
		print("    no solved hops recorded")
		return

	var worst: Dictionary = _hops[0]
	for h in _hops:
		if absf(h["offset"]) > absf(worst["offset"]):
			worst = h

	var over := 0
	for h in _hops:
		if absf(h["offset"]) > INTERESTING:
			over += 1
	print("    %d of %d hops beyond %.0f ms" % [over, _hops.size(), INTERESTING * 1000.0])

	for h in _hops:
		if absf(h["offset"]) > INTERESTING:
			_dump("OUTLIER", h, names)
	_dump("worst", worst, names)


## Print one hop with everything needed to tell the two failure families apart.
func _dump(label: String, h: Dictionary, names: Array) -> void:
	var tname: String = names[int(h["type"])] if int(h["type"]) >= 0 else "none"
	var solved: float = h["solved"]
	var real: float = h["real"]
	var audio: float = h["audio"]
	print("    %s: tier %d gained %d onto %s at %.1fs, %+.1f ms off the beat"
		% [label, h["tier"], h["gained"], tname, h["at"], h["offset"] * 1000.0])
	print("        flight  solved %.1f ms | real %.1f ms | audio %.1f ms"
		% [solved * 1000.0, real * 1000.0, audio * 1000.0])
	print("        real - solved  %+.1f ms   (simulation vs solver)"
		% ((real - solved) * 1000.0))
	print("        audio - real   %+.1f ms   (song clock vs wall clock)"
		% ((audio - real) * 1000.0))
	print("        rise    solved %.1f px | actual %.1f px"
		% [h["rise_solved"], h["rise_actual"]])
	# A non-zero dy means the platform was not where its tier says it should be,
	# which would explain an arc that ended in the wrong place with a perfect
	# clock and a perfect simulation.
	print("        platform y %.1f, %+.1f px from where tier %d should sit"
		% [h["platform_y"], h["platform_dy"], h["tier"]])
	# THE decisive line. Screen y grows downward, so a legitimate landing is
	# positive (descending). Negative means the floor caught a rising body.
	var vy: float = h["land_vy"]
	var sense := "descending"
	if vy < -1.0:
		sense = "*** RISING, the floor caught a body going UP ***"
	elif vy <= 1.0:
		sense = "*** STATIONARY ***"
	print("        entered the landing at vy %+.1f px/s (%s) after %d physics frames"
		% [vy, sense, h["land_frames"]])


# --- Steering (same controller as gameplay_test) ----------------------------

func _steer(spawner: Node2D) -> void:
	# has_tier, not target_x < 0. A MOVING platform sways up to 150px around its
	# home x, so one homed near the left edge is at a negative x while perfectly
	# alive, and this controller used to give up on steering toward it.
	var next_tier: int = _player.current_tier + 1
	var target_x: float = spawner.x_of_tier(next_tier)
	if not spawner.has_tier(next_tier):
		_release()
		return

	var w: float = Tuning.PLAYFIELD_WIDTH
	var dx: float = fposmod(target_x - _player.global_position.x + w * 0.5, w) - w * 0.5
	var vx: float = _player.velocity.x
	var braking_distance: float = (vx * vx) / (2.0 * Tuning.AIR_ACCEL)

	if absf(dx) < 6.0 and absf(vx) < 60.0:
		_release()
		return

	var want_right: bool
	if dx > 0.0:
		want_right = not (vx > 0.0 and braking_distance >= dx)
	else:
		want_right = (vx < 0.0 and braking_distance >= -dx)

	if want_right:
		Input.action_release("move_left")
		Input.action_press("move_right")
	else:
		Input.action_release("move_right")
		Input.action_press("move_left")


func _release() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
