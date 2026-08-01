extends Node2D

## Generates the endless platform climb.
##
## Platforms sit on a strict tier grid, one per tier, TIER_RISE apart. That
## regularity is required: irregular spacing would make flight time depend on
## where the next platform happened to be and the rhythm would collapse. All
## variety is horizontal.
##
## Reachability is free because of wrapping: the player can cross either edge,
## so the greatest distance between two x positions is half the playfield, well
## inside what one hop covers. No spread constraint is needed at any difficulty.
##
## Platforms are pooled, not freed. An endless climb would otherwise churn
## thousands of nodes and the resulting GC pauses are exactly the frame hitches
## a rhythm game cannot afford.

const PlatformScene: PackedScene = preload("res://scenes/Platform.tscn")

const LOOKAHEAD_TIERS: int = 14
const TRAIL_TIERS: int = 3

var base_y: float = 0.0

var _highest_tier: int = -1
var _live: Dictionary = {}
var _pool: Array[Node2D] = []
var _last_x: float = Tuning.PLAYFIELD_WIDTH * 0.5

## Prevents two special platforms in a row. See _pick_type.
var _last_was_special: bool = false

## Seeded per run so a layout is reproducible from its seed, which makes reports
## of an "impossible" spawn diagnosable.
var _rng := RandomNumberGenerator.new()


func reset(start_y: float, seed_value: int = 0) -> void:
	base_y = start_y
	_highest_tier = -1
	_last_x = Tuning.PLAYFIELD_WIDTH * 0.5
	_last_was_special = false

	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value

	for tier in _live.keys():
		_recycle(tier)
	_live.clear()

	# Tier 0 sits dead centre beneath the player, so every run opens fairly.
	_spawn_tier(0, Tuning.PLAYFIELD_WIDTH * 0.5)


## Higher tier means smaller y, because screen y grows downward.
func tier_y(tier: int) -> float:
	return base_y - float(tier) * Tuning.TIER_RISE


func update_for(player_tier: int, camera_bottom_y: float) -> void:
	while _highest_tier < player_tier + LOOKAHEAD_TIERS:
		_spawn_next()

	var cutoff := camera_bottom_y + float(TRAIL_TIERS) * Tuning.TIER_RISE
	for tier in _live.keys():
		if (_live[tier] as Node2D).global_position.y > cutoff:
			_recycle(tier)


## x of a tier's platform, or -1 if not live. Used by tests and the HUD.
func x_of_tier(tier: int) -> float:
	if not _live.has(tier):
		return -1.0
	return (_live[tier] as Node2D).global_position.x


func _spawn_next() -> void:
	var tier := _highest_tier + 1
	var progress := clampf(float(tier) / Tuning.RAMP_TIERS, 0.0, 1.0)
	var spread := lerpf(Tuning.SPREAD_START, Tuning.SPREAD_MAX, progress)

	var max_offset := spread * Tuning.PLAYFIELD_WIDTH
	var offset := _rng.randf_range(-max_offset, max_offset)

	# Bias away from tiny offsets: a near-zero drift means the player need not
	# move at all, which is dead air mid-climb.
	if absf(offset) < Tuning.PLATFORM_HALF_WIDTH:
		offset = Tuning.PLATFORM_HALF_WIDTH * signf(offset if offset != 0.0 else 1.0)

	# Wrap rather than clamp, or platforms would pile against the edges once the
	# spread grew large.
	_spawn_tier(tier, fposmod(_last_x + offset, Tuning.PLAYFIELD_WIDTH))


func _spawn_tier(tier: int, x: float) -> void:
	var p := _acquire()
	# Platforms narrow with altitude, tightening landing precision without
	# touching the beat cadence.
	var progress := clampf(float(tier) / Tuning.RAMP_TIERS, 0.0, 1.0)
	var type := _pick_type(tier)
	var amplitude := 0.0
	if type == Tuning.PlatformType.MOVING:
		amplitude = lerpf(Tuning.MOVE_AMPLITUDE_START,
			Tuning.MOVE_AMPLITUDE_MAX, progress)

	p.setup(tier, Vector2(x, tier_y(tier)),
		lerpf(1.0, 0.62, progress), type, amplitude)
	_live[tier] = p
	_last_x = x
	_highest_tier = maxi(_highest_tier, tier)


## Choose a platform behaviour for a tier.
##
## Types unlock with height and then grow more frequent, so the climb gets
## harder in kind as well as in degree. Two guards keep it fair:
##
##   * tier 0 and 1 are always NORMAL, so a run never opens on a hazard;
##   * two special platforms never appear back to back, because consecutive
##     hazards can demand a route the player cannot reach in one hop.
func _pick_type(tier: int) -> Tuning.PlatformType:
	if tier <= 1 or _last_was_special:
		_last_was_special = false
		return Tuning.PlatformType.NORMAL

	var available: Array[Tuning.PlatformType] = []
	if tier >= Tuning.UNLOCK_MOVING:
		available.append(Tuning.PlatformType.MOVING)
	if tier >= Tuning.UNLOCK_CRUMBLING:
		available.append(Tuning.PlatformType.CRUMBLING)
	if tier >= Tuning.UNLOCK_PHASING:
		available.append(Tuning.PlatformType.PHASING)
	if available.is_empty():
		return Tuning.PlatformType.NORMAL

	var progress := clampf(float(tier) / Tuning.RAMP_TIERS, 0.0, 1.0)
	var chance := lerpf(Tuning.SPECIAL_CHANCE_START,
		Tuning.SPECIAL_CHANCE_MAX, progress)
	if _rng.randf() > chance:
		return Tuning.PlatformType.NORMAL

	_last_was_special = true
	return available[_rng.randi() % available.size()]


func _acquire() -> Node2D:
	if _pool.is_empty():
		var p := PlatformScene.instantiate()
		add_child(p)
		return p
	var reused: Node2D = _pool.pop_back()
	reused.visible = true
	reused.process_mode = Node.PROCESS_MODE_INHERIT
	return reused


func _recycle(tier: int) -> void:
	if not _live.has(tier):
		return
	var p: Node2D = _live[tier]
	_live.erase(tier)
	p.visible = false
	# Stop it processing while pooled: an invisible platform still running its
	# beat-pulse redraw is pure waste, and there can be hundreds over a run.
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.global_position = Vector2(-10000, -10000)
	_pool.append(p)
