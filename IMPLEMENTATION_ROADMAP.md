# Bounce Ascent - Implementation Roadmap & Issue Resolution

**Date**: 2025-10-11
**Based On**: GitHub Issue #1 + Godot Best Practices Analysis
**Priority System**: 🔴 Critical | 🟡 High | 🟢 Medium | 🔵 Low

---

## Overview

This roadmap combines:
1. **User Feedback** from GitHub Issue #1 (gameplay improvements)
2. **Technical Improvements** from Godot Best Practices analysis
3. **Prioritized Implementation Plan** with effort estimates

---

## Phase 1: Core Technical Refactoring (Foundation)

### 🔴 CRITICAL - Scene-Based Architecture Migration
**Issue**: All entities created procedurally in code
**Impact**: Difficult to iterate, no visual development workflow
**Effort**: 4-6 hours
**Priority**: Do this FIRST - enables all future development

#### Implementation Steps:

##### 1.1 Create Player.tscn (1 hour)
```
Current: Player created in Game.gd:42-46
Goal: Create reusable Player scene
```

**File**: `scenes/player/Player.tscn`
**Structure**:
```
Player (CharacterBody2D)
├── CollisionShape2D
├── BallSprite (Sprite2D)
│   └── Texture: res://assets/sprites/player-ball.png
├── TimingRingVisual (Node2D)
│   └── Script: draws timing ring
└── ComboLabel (Label)
```

**Script Changes** (`scripts/Player.gd`):
```gdscript
# REMOVE from _ready():
# var collision = CollisionShape2D.new()
# var circle = CircleShape2D.new()
# ...all the setup code

# REPLACE WITH:
@onready var ball_sprite: Sprite2D = $BallSprite
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var combo_label: Label = $ComboLabel
```

**Benefits**:
- ✅ Adjust player size visually in editor
- ✅ Add glow effects, particles, animations easily
- ✅ Test player independently (F6)

##### 1.2 Create Platform Scenes (2 hours)
**Files**:
- `scenes/platforms/Platform.tscn` (base)
- `scenes/platforms/MovingPlatform.tscn` (inherits Platform.tscn)
- `scenes/platforms/BreakablePlatform.tscn` (inherits Platform.tscn)
- `scenes/platforms/TemporaryPlatform.tscn` (inherits Platform.tscn)

**Scene Inheritance Setup**:
```
Platform.tscn (StaticBody2D)
├── CollisionShape2D
├── PlatformSprite (Sprite2D)
└── [Attach Platform.gd]

MovingPlatform.tscn (inherits Platform.tscn)
└── [Attach MovingPlatform.gd]
└── Add: AnimationPlayer for smooth movement
```

**Godot Feature**: Use **Scene → New Inherited Scene** to create variants.

**Script Changes** (`PlatformSpawner.gd:101`):
```gdscript
# OLD:
var platform = StaticBody2D.new()
platform.set_script(platform_script)

# NEW:
const PLATFORM_SCENES = {
	PlatformType.STATIC: preload("res://scenes/platforms/Platform.tscn"),
	PlatformType.MOVING: preload("res://scenes/platforms/MovingPlatform.tscn"),
	PlatformType.BREAKABLE: preload("res://scenes/platforms/BreakablePlatform.tscn"),
	PlatformType.TEMPORARY: preload("res://scenes/platforms/TemporaryPlatform.tscn"),
}

func create_platform_for_difficulty(height: int) -> Platform:
	var platform_type = determine_platform_type(height)
	var platform = PLATFORM_SCENES[platform_type].instantiate()
	return platform
```

##### 1.3 Create Camera Scene (30 minutes)
**File**: `scenes/camera/GameCamera.tscn`

**Structure**:
```
GameCamera (Camera2D)
├── ScreenShakeAnimation (AnimationPlayer)  # For future screen shake
└── [Attach GameCamera.gd]
```

**Export Variables** (add to GameCamera.gd):
```gdscript
@export_group("Scrolling")
@export var base_scroll_speed: float = 30.0
@export var max_scroll_speed: float = 300.0
@export var space_speed_multiplier: float = 2.0

@export_group("Death Zone")
@export var death_zone_offset: float = 600.0
```

**Benefits**: Tweak camera behavior in inspector without code changes.

##### 1.4 Refactor Game.tscn (1 hour)
**File**: `scenes/game/Game.tscn`

**Current**: Everything created in `_ready()`
**New**: Compose from subscenes

**Visual Structure in Editor**:
```
Game (Node2D)
├── DynamicBackground (ColorRect) [instanced scene]
├── GameCamera (Camera2D) [instanced scene]
├── Player (CharacterBody2D) [instanced scene]
├── PlatformSpawner (Node2D) [instanced scene]
├── UILayer (CanvasLayer)
│   └── GameUI [instanced scene]
└── CountdownOverlay (CanvasLayer)
    └── CountdownUI [new scene]
```

**Script Changes** (`Game.gd`):
```gdscript
# OLD _ready():
# background = ColorRect.new()
# camera = Camera2D.new()
# ...

# NEW _ready():
@onready var background: ColorRect = $DynamicBackground
@onready var camera: Camera2D = $GameCamera
@onready var player: CharacterBody2D = $Player
@onready var platform_spawner: Node2D = $PlatformSpawner
@onready var ui: CanvasLayer = $UILayer/GameUI

func _ready():
	# Just connect signals - scene structure already set up!
	camera.player_fell_behind.connect(_on_player_fell_behind)
	player.landed_on_platform.connect(_on_player_landed)
	platform_spawner.set_camera(camera)
	GameManager.start_game_session()
```

**Impact**: 80% less code in Game.gd, visual workflow enabled.

---

## Phase 2: Gameplay Improvements (Address Issue #1)

### 🟡 HIGH PRIORITY - Jump Rhythm Enhancement

#### Issue #1.1: "Missing Jumping Rhythm should have varying jump heights"
**Current State**: Jump height varies (PERFECT > GREAT > BASE), but it's not obvious enough.

**Root Cause Analysis**:
- Timing windows are small (0.1s perfect, 0.2s great)
- Visual feedback exists but may not be clear enough
- Combo system is hidden (number inside ball)

**Implementation** (2 hours):

##### 2.1.1 Enhanced Visual Feedback
Create `JumpFeedbackEffect.tscn`:
```
JumpFeedbackEffect (Node2D)
├── ImpactRing (Sprite2D)  # Expands outward on jump
├── StarBurst (GPUParticles2D)  # Particles for PERFECT jumps
├── AnimationPlayer
└── [Attach JumpFeedback.gd]
```

**Script** (`scripts/JumpFeedback.gd`):
```gdscript
extends Node2D

func show_feedback(quality: String):
	match quality:
		"perfect":
			# Green ring + star particles
			$ImpactRing.modulate = Color(0.2, 1.0, 0.2)
			$StarBurst.emitting = true
			play_perfect_animation()
		"great":
			# Yellow ring
			$ImpactRing.modulate = Color(1.0, 0.85, 0.0)
			play_great_animation()
		"base", "early":
			# Gray puff (missed timing)
			$ImpactRing.modulate = Color(0.5, 0.5, 0.5, 0.5)
			play_miss_animation()
```

**Connect to Player**:
```gdscript
# Player.gd
@onready var jump_feedback: Node2D = $JumpFeedbackEffect

func execute_bounce(bounce_velocity: float, quality: String):
	velocity.y = bounce_velocity
	jump_feedback.show_feedback(quality)
	jumped.emit(quality)
```

##### 2.1.2 Audio Feedback (Addresses "Add jump sound effects")
**Files Needed**:
- `assets/audio/jump_perfect.ogg` (high pitch)
- `assets/audio/jump_great.ogg` (medium pitch)
- `assets/audio/jump_base.ogg` (low pitch)

**Implementation**:
```gdscript
# Add to Player.tscn:
Player
└── AudioPlayers
    ├── PerfectJumpSound (AudioStreamPlayer)
    ├── GreatJumpSound (AudioStreamPlayer)
    └── BaseJumpSound (AudioStreamPlayer)

# In Player.gd:
@onready var perfect_sound: AudioStreamPlayer = $AudioPlayers/PerfectJumpSound
@onready var great_sound: AudioStreamPlayer = $AudioPlayers/GreatJumpSound
@onready var base_sound: AudioStreamPlayer = $AudioPlayers/BaseJumpSound

func execute_bounce(bounce_velocity: float, quality: String):
	velocity.y = bounce_velocity
	jump_feedback.show_feedback(quality)

	# Play audio
	match quality:
		"perfect": perfect_sound.play()
		"great": great_sound.play()
		_: base_sound.play()

	jumped.emit(quality)
```

**Sound Effect Generation**: Use [SFXR](https://sfxr.me/) or [Chiptone](https://sfbgames.itch.io/chiptone) for free retro sounds.

##### 2.1.3 Combo UI Enhancement
**Issue**: Combo number inside ball is hard to see during fast gameplay.

**Create** `ComboDisplay.tscn` (HUD element):
```
ComboDisplay (Control)
├── ComboLabel (Label) "COMBO x5"
├── MultiplierLabel (Label) "1.5x SPEED"
└── AnimationPlayer (pulse on combo increase)
```

**Position**: Top-center of screen (always visible).

**Update GameUI.gd**:
```gdscript
@onready var combo_display: Control = $ComboDisplay

func _on_player_jumped(quality: String, combo_level: int):
	if quality in ["perfect", "great"]:
		combo_display.show_combo(combo_level)
	else:
		combo_display.hide_combo()
```

**Impact**: Players now clearly see:
1. Visual ring expansion (impact)
2. Color-coded feedback (green/yellow/gray)
3. Audio feedback (pitch variation)
4. Combo counter on HUD (persistent)

---

### 🟡 HIGH PRIORITY - Platform Spawning Improvements

#### Issue #1.2: "Moving Platforms Should be introduced much earlier"
**Current**: Moving platforms at height 50+
**Recommended**: Introduce at height 10-15

**Fix** (`PlatformSpawner.gd:11-14`):
```gdscript
# OLD:
const TIER_2_HEIGHT = 50   # Moving platforms

# NEW:
const TIER_1_HEIGHT = 10   # Tutorial zone (static only)
const TIER_2_HEIGHT = 15   # Moving platforms introduced
const TIER_3_HEIGHT = 50   # Breakable platforms
const TIER_4_HEIGHT = 100  # Temporary platforms
const TIER_5_HEIGHT = 150  # Max difficulty
```

**Updated Difficulty Curve**:
```gdscript
func create_platform_for_difficulty(height: int) -> Platform:
	if height < TIER_1_HEIGHT:
		# Tutorial: 100% static
		return create_static_platform()
	elif height < TIER_2_HEIGHT:
		# Early game: 70% static, 30% moving
		return create_static_platform() if randf() < 0.7 else create_moving_platform()
	elif height < TIER_3_HEIGHT:
		# Mid game: 40% static, 40% moving, 20% breakable
		# ...etc
```

**Benefit**: Players learn moving platforms earlier, smoother difficulty curve.

---

#### Issue #1.3: "Platform Placement is too random, needs intentionality/rules"
**Problem**: Completely random X position can create impossible jumps.

**Solution**: Smart Placement Algorithm (1.5 hours)

**Create** `scripts/PlatformPlacementValidator.gd`:
```gdscript
class_name PlatformPlacementValidator

## Validates that platform placement is physically possible to reach.
## Prevents impossible jumps and ensures fair difficulty.

const MAX_HORIZONTAL_DISTANCE = 300.0  # Max player can move between jumps
const MAX_VERTICAL_DISTANCE = 150.0     # Max jump height

static func is_placement_valid(
	new_platform_pos: Vector2,
	previous_platform_pos: Vector2,
	platform_type: Platform.PlatformType
) -> bool:
	var horizontal_distance = abs(new_platform_pos.x - previous_platform_pos.x)
	var vertical_distance = new_platform_pos.y - previous_platform_pos.y  # Negative = upward

	# Check horizontal reachability
	if horizontal_distance > MAX_HORIZONTAL_DISTANCE:
		return false

	# Check vertical reachability (allow combo jumps for high platforms)
	if abs(vertical_distance) > MAX_VERTICAL_DISTANCE * 1.5:  # 1.5x for combos
		return false

	# Moving platforms need more horizontal space
	if platform_type == Platform.PlatformType.MOVING:
		if horizontal_distance < 100:  # Too close = overlapping movement
			return false

	return true

static func suggest_placement(
	previous_platform_pos: Vector2,
	platform_type: Platform.PlatformType,
	difficulty_height: int
) -> Vector2:
	var attempts = 0
	var suggested_pos: Vector2

	while attempts < 10:
		# Generate random position within constraints
		var horizontal_offset = randf_range(-250, 250)
		var vertical_spacing = randf_range(80, 120)

		suggested_pos = Vector2(
			previous_platform_pos.x + horizontal_offset,
			previous_platform_pos.y - vertical_spacing
		)

		# Clamp to screen bounds
		suggested_pos.x = clamp(suggested_pos.x, 60, 740)

		if is_placement_valid(suggested_pos, previous_platform_pos, platform_type):
			return suggested_pos

		attempts += 1

	# Fallback: Safe placement directly above
	return Vector2(previous_platform_pos.x, previous_platform_pos.y - 100)
```

**Update PlatformSpawner.gd**:
```gdscript
var last_platform_position: Vector2 = Vector2(400, 920)  # Track last spawn

func spawn_platform_at_height(y_position: float, height: int):
	var platform = create_platform_for_difficulty(height)

	# NEW: Use smart placement instead of random
	var platform_position = PlatformPlacementValidator.suggest_placement(
		last_platform_position,
		platform.platform_type,
		height
	)

	platform.position = platform_position
	last_platform_position = platform_position

	add_child(platform)
	platforms.append(platform)
```

**Impact**:
- ✅ No more impossible jumps
- ✅ Fair difficulty progression
- ✅ Moving platforms won't overlap
- ✅ Player skill determines success, not RNG

---

### 🟢 MEDIUM PRIORITY - New Platform Types

#### Issue #1.4: "Add Spiky Platform, Icy Platform"

##### 2.4.1 Spiky Platform (1 hour)
**Behavior**: Deals damage, reduces combo by 1 level.

**File**: `scenes/platforms/SpikyPlatform.tscn` (inherits Platform.tscn)

**Script** (`scripts/SpikyPlatform.gd`):
```gdscript
extends Platform

@onready var spike_particles: GPUParticles2D = $SpikeParticles

func on_player_land():
	# Reduce player combo
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.combo_level = max(0, player.combo_level - 1)
		player.current_bounce_interval = player.BOUNCE_INTERVAL

		# Visual feedback
		spike_particles.emitting = true

		# Screen shake (if implemented)
		GameManager.trigger_screen_shake(0.3, 5.0)
```

**Add to Spritesheet** (`Platform.gd:82`):
```gdscript
PlatformType.SPIKY:
	atlas.region = Rect2(2176, 896, 128, 128)  # block_spiky
	platform_color = Color(1.0, 0.4, 0.0)  # Orange
```

**Introduce at Tier 4+** (height 100+):
```gdscript
# PlatformSpawner.gd
elif height >= TIER_4_HEIGHT:
	var rand = randf()
	if rand < 0.05:  # 5% chance
		platform_script = spiky_platform_scene
```

##### 2.4.2 Icy Platform (1.5 hours)
**Behavior**: Player slides (reduced friction), harder to control.

**File**: `scenes/platforms/IcyPlatform.tscn`

**Script** (`scripts/IcyPlatform.gd`):
```gdscript
extends Platform

const ICY_FRICTION = 0.1  # Very low friction

func on_player_land():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.is_on_ice = true  # Flag for player to use different physics

func _on_player_left():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.is_on_ice = false
```

**Update Player Physics** (`Player.gd:155`):
```gdscript
var is_on_ice: bool = false

# In _physics_process:
if direction != 0:
	velocity.x = direction * MOVE_SPEED
else:
	var friction_multiplier = 0.1 if is_on_ice else 1.0
	velocity.x = move_toward(velocity.x, 0, MOVE_SPEED * delta * 10 * friction_multiplier)
```

**Visual**: Add ice shader with transparency/gloss effect.

---

### 🟢 MEDIUM PRIORITY - Power-Up System

#### Issue #1.5: "Add Power Ups to increase jump height, speed, grace period"

**Architecture** (2 hours):

##### Create PowerUp Base Class
**File**: `scripts/PowerUp.gd`
```gdscript
extends Area2D
class_name PowerUp

enum PowerUpType {
	JUMP_BOOST,      # Increase jump height temporarily
	SPEED_BOOST,     # Increase movement speed
	GRACE_PERIOD,    # Extend timing windows
	SHIELD,          # Protect from spiky platforms
}

@export var power_up_type: PowerUpType = PowerUpType.JUMP_BOOST
@export var duration: float = 5.0

signal collected(power_up_type: PowerUpType)

func _ready():
	add_to_group("powerup")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		collected.emit(power_up_type)
		apply_effect(body)
		queue_free()

func apply_effect(player):
	# Override in subclasses
	pass
```

##### Specific Power-Ups
**JumpBoostPowerUp.gd**:
```gdscript
extends PowerUp

func apply_effect(player):
	player.apply_jump_boost(duration)
```

**In Player.gd**:
```gdscript
var active_power_ups: Dictionary = {}

func apply_jump_boost(duration: float):
	active_power_ups["jump_boost"] = duration
	# Temporarily modify jump constants

func _physics_process(delta):
	# Update power-up timers
	for power_up in active_power_ups.keys():
		active_power_ups[power_up] -= delta
		if active_power_ups[power_up] <= 0:
			active_power_ups.erase(power_up)

	# Apply power-up effects to jump
	var jump_multiplier = 1.5 if "jump_boost" in active_power_ups else 1.0
	# ...use multiplier in execute_bounce()
```

**Spawn in PlatformSpawner**:
```gdscript
func spawn_power_up_maybe(platform_position: Vector2):
	if randf() < 0.05:  # 5% chance per platform
		var power_up = load("res://scenes/powerups/JumpBoostPowerUp.tscn").instantiate()
		power_up.position = platform_position + Vector2(0, -40)  # Float above platform
		add_child(power_up)
```

---

### 🟢 MEDIUM PRIORITY - Negative Effects

#### Issue #1.6: "Introduce Negative Effects: Shaky screen, Slower rhythm bar"

##### Screen Shake Effect (30 minutes)
**Add to GameCamera.gd**:
```gdscript
var shake_amount: float = 0.0
var shake_duration: float = 0.0

func trigger_shake(duration: float, intensity: float):
	shake_duration = duration
	shake_amount = intensity

func _process(delta):
	if shake_duration > 0:
		shake_duration -= delta
		offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
	else:
		offset = Vector2.ZERO

	# ...normal camera logic
```

**Connect to GameManager**:
```gdscript
# GameManager.gd
signal screen_shake_requested(duration: float, intensity: float)

func trigger_screen_shake(duration: float, intensity: float):
	screen_shake_requested.emit(duration, intensity)
```

##### Rhythm Slowdown (1 hour)
**Debuff System**:
```gdscript
# Player.gd
var rhythm_slowdown_active: bool = false

func apply_rhythm_slowdown(duration: float):
	rhythm_slowdown_active = true
	await get_tree().create_timer(duration).timeout
	rhythm_slowdown_active = false

# In _physics_process for bounce timing:
var timing_multiplier = 0.5 if rhythm_slowdown_active else 1.0
var adjusted_timing_window = TIMING_WINDOW_PERFECT * timing_multiplier
```

**Trigger on Bad Jumps**:
```gdscript
# Player.gd:203-207
else:
	# Early or late - reset combo AND apply penalty
	combo_level = 0
	current_bounce_interval = BOUNCE_INTERVAL
	apply_rhythm_slowdown(2.0)  # NEW: 2 second penalty
	execute_bounce(BOUNCE_BASE, "early")
```

---

### 🔵 LOW PRIORITY - Obstacles & Enemies

#### Issue #1.7: "Add Monsters/Bullet Bills as extra obstacles"

**Complexity**: Medium-High (3-4 hours)
**Recommendation**: Implement after Phase 2 is complete.

##### Moving Enemy Example
**File**: `scenes/enemies/BulletBill.tscn`
```
BulletBill (Area2D)
├── Sprite2D (animated sprite)
├── CollisionShape2D
├── VisibleOnScreenNotifier2D
└── [Attach BulletBill.gd]
```

**Script**:
```gdscript
extends Area2D

@export var move_speed: float = 200.0
@export var direction: Vector2 = Vector2(-1, 0)  # Move left

func _ready():
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	position += direction * move_speed * delta

func _on_body_entered(body):
	if body.is_in_group("player"):
		# Player hit - trigger game over or damage
		GameManager.trigger_player_hit()
		queue_free()
```

**Spawn from PlatformSpawner**:
```gdscript
func spawn_enemy_maybe(height: int):
	if height > 100 and randf() < 0.1:  # 10% chance at high altitudes
		var enemy = preload("res://scenes/enemies/BulletBill.tscn").instantiate()
		enemy.position = Vector2(800, camera_ref.position.y - 200)
		add_child(enemy)
```

---

## Phase 3: Audio & Polish

### 🟡 HIGH PRIORITY - Audio System

#### Issue #1.8: "Add background music and sound effects"

##### 3.1 Background Music (1 hour)
**Files Needed**:
- `assets/audio/music/menu_theme.ogg`
- `assets/audio/music/gameplay_theme.ogg`
- `assets/audio/music/gameplay_intense.ogg` (for space zone)

**Implementation**:
```gdscript
# Create AudioManager.gd (singleton)
extends Node

var menu_music: AudioStreamPlayer
var gameplay_music: AudioStreamPlayer
var intense_music: AudioStreamPlayer

func _ready():
	menu_music = AudioStreamPlayer.new()
	menu_music.stream = load("res://assets/audio/music/menu_theme.ogg")
	menu_music.bus = "Music"
	add_child(menu_music)

	# ...setup other tracks

func play_menu_music():
	stop_all_music()
	menu_music.play()

func play_gameplay_music():
	stop_all_music()
	gameplay_music.play()

func transition_to_intense():
	# Crossfade from gameplay to intense
	var tween = create_tween()
	tween.tween_property(gameplay_music, "volume_db", -80, 2.0)
	tween.parallel().tween_property(intense_music, "volume_db", 0, 2.0)
	intense_music.play()

func stop_all_music():
	menu_music.stop()
	gameplay_music.stop()
	intense_music.stop()
```

**Add to project.godot**:
```ini
[autoload]
AudioManager="*res://scripts/AudioManager.gd"
```

**Trigger Music Changes**:
```gdscript
# Game.gd _ready():
AudioManager.play_gameplay_music()

# GameCamera.gd (when entering space zone):
if player_height > 600:
	AudioManager.transition_to_intense()
```

**Free Music Resources**:
- [Incompetech](https://incompetech.com/music/royalty-free/) - Free royalty-free music
- [OpenGameArt](https://opengameart.org/) - Community music
- [Purple Planet Music](https://www.purple-planet.com/) - Free game music

##### 3.2 Sound Effects Library (1 hour)
**Add to Player.tscn**:
```
Player
└── SoundEffects
    ├── JumpPerfect (AudioStreamPlayer)
    ├── JumpGreat (AudioStreamPlayer)
    ├── JumpBase (AudioStreamPlayer)
    ├── Land (AudioStreamPlayer)
    ├── ComboIncrease (AudioStreamPlayer)
    └── ComboLost (AudioStreamPlayer)
```

**Platform Sounds** (add to Platform.tscn):
```
Platform
└── BreakSound (AudioStreamPlayer)  # For breakable platforms
```

**UI Sounds** (add to MainMenu.tscn, GameOver.tscn):
```
└── UIClickSound (AudioStreamPlayer)
```

---

### 🟢 MEDIUM PRIORITY - Tutorial & Onboarding

#### Issue #1.9: "Create quick intro screen, infographic, display controls on start up"

##### 3.3.1 Tutorial Overlay (2 hours)
**File**: `scenes/ui/TutorialOverlay.tscn`

**Structure**:
```
TutorialOverlay (CanvasLayer)
├── Panel (semi-transparent black)
├── TitleLabel "HOW TO PLAY"
├── ControlsSection
│   ├── Icon (keyboard graphic)
│   └── Text "←/→ or A/D: Move"
│   └── Text "SPACE/W/↑: Time your jump"
├── TimingSection
│   ├── GreenCircle "PERFECT! +Max Height"
│   ├── YellowCircle "GREAT! +Good Height"
│   └── GrayCircle "MISS! No Bonus"
├── ComboSection
│   └── Text "Chain perfect jumps for COMBOS!"
├── StartButton "PRESS SPACE TO START"
└── [Attach TutorialOverlay.gd]
```

**Script**:
```gdscript
extends CanvasLayer

func _ready():
	# Show on first play only
	if GameManager.current_profile.total_runs == 0:
		show()
	else:
		queue_free()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		hide_tutorial()

func hide_tutorial():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	queue_free()
```

**Add to Game.tscn**:
```gdscript
# Game.gd _ready():
if GameManager.current_profile.total_runs == 0:
	var tutorial = preload("res://scenes/ui/TutorialOverlay.tscn").instantiate()
	add_child(tutorial)
```

##### 3.3.2 Control Reminders (30 minutes)
**Add to GameUI.tscn** (bottom-left corner):
```
GameUI
└── ControlHints (VBoxContainer)
    ├── Label "←→: Move"
    ├── Label "SPACE: Jump"
    └── FadeOutTimer (auto-hide after 10 seconds)
```

---

## Phase 4: Advanced Features (Future)

### 🔵 LOW PRIORITY - Additional Enhancements

#### 4.1 Leaderboard System (4-6 hours)
- Local high score list (top 10 runs)
- Online leaderboards (requires backend + Steamworks/PlayFab)

#### 4.2 Unlockable Ball Skins (2-3 hours)
- Unlock new colors/patterns based on achievements
- "Reach height 1000" → Unlock galaxy skin

#### 4.3 Daily Challenges (3-4 hours)
- Seed-based generation (same platforms for all players)
- Special challenge modes (no combos, only breakable platforms, etc.)

#### 4.4 Replay System (4-5 hours)
- Record inputs for runs
- Watch replays of high scores
- Ghost racing (race against your best run)

---

## Implementation Priority Summary

### Week 1: Foundation
1. ✅ Scene-based architecture migration (Phase 1)
2. ✅ Type hints and code cleanup
3. ✅ Smart platform placement algorithm

**Outcome**: Solid technical foundation, easier to iterate.

### Week 2: Core Gameplay
1. ✅ Enhanced jump feedback (visual + audio)
2. ✅ Improved difficulty curve (earlier moving platforms)
3. ✅ New platform types (spiky, icy)
4. ✅ Basic audio system (music + SFX)

**Outcome**: Addresses all major gameplay feedback from Issue #1.

### Week 3: Polish & Content
1. ✅ Power-up system
2. ✅ Negative effects (screen shake, rhythm slowdown)
3. ✅ Tutorial overlay
4. ✅ Final balancing and testing

**Outcome**: Feature-complete, polished experience.

### Week 4+: Advanced Features (Optional)
1. Enemies/obstacles
2. Leaderboards
3. Unlockables
4. Daily challenges

---

## Testing Checklist

After each phase, test:
- [ ] Player can complete tutorial
- [ ] All platform types spawn correctly
- [ ] Jump timing feels responsive
- [ ] Audio plays without crackling
- [ ] No impossible platform placements
- [ ] Combo system is clear and satisfying
- [ ] Power-ups work as expected
- [ ] Game over triggers correctly
- [ ] Save/load preserves data
- [ ] Performance is smooth (60 FPS)

---

## Conclusion

This roadmap provides a **structured path** from the current codebase to a polished, feature-rich game that:
1. ✅ Follows Godot best practices (scene composition, type safety)
2. ✅ Addresses all user feedback from GitHub Issue #1
3. ✅ Maintains clean, maintainable code architecture
4. ✅ Provides a clear implementation plan with effort estimates

**Recommended Starting Point**: Phase 1 (Scene-Based Architecture) - this single change will make all future development 10x easier.

**Total Estimated Effort**:
- Phase 1: 4-6 hours
- Phase 2: 10-12 hours
- Phase 3: 4-5 hours
- **Total**: 18-23 hours for core improvements

Good luck with the implementation! 🚀

---

**Next Steps**:
1. Read through this roadmap completely
2. Set up a development branch: `git checkout -b refactor/scene-architecture`
3. Start with Phase 1.1 (Player.tscn creation)
4. Test frequently, commit often
5. Refer to [GODOT_BEST_PRACTICES_ANALYSIS.md](./GODOT_BEST_PRACTICES_ANALYSIS.md) for technical details
