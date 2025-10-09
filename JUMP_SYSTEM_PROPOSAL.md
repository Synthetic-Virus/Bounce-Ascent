# Jump System Redesign Proposal

## Current Problem
- Ball doesn't jump at all due to logic error (elif instead of separate checks)
- Confusing interaction between auto-jump, manual jump, and super jump
- Rubber bounce effect conflicts with jump mechanics

## Proposed System

### Option 1: Bounce-Based System (Simpler)
**How it works:**
- Ball ALWAYS bounces when landing (rubber ball effect)
- Holding spacebar CHARGES the bounce for bigger height
- No separate manual jump - everything is bounce-based

**Implementation:**
1. On landing: Apply bounce velocity based on charge level
2. While grounded: Charge meter fills if holding spacebar (0-1.5 seconds)
3. Release happens automatically when:
   - Auto-jump timer reaches 1.5s (forced bounce)
   - Player releases spacebar (immediate charged bounce)
   - Player holds for max charge (super bounce)

**Charge Levels:**
- 0.0s charge = Small bounce (-200 velocity)
- 0.5s charge = Normal bounce (-500 velocity)
- 1.5s charge = Super bounce (-750 velocity)
- Linear interpolation between levels

**Benefits:**
- Simple mental model: "charge and release"
- Natural rubber ball feel
- Clear risk/reward: charge longer = jump higher, but wait longer
- No confusing manual vs auto distinction

---

### Option 2: Dual-Mode System (More Control)
**How it works:**
- Ball has TWO jump modes: Bounce and Jump
- Bounce: Automatic small hop on landing (rubber effect)
- Jump: Manual input overrides the bounce for bigger jumps

**Implementation:**
1. **Landing Bounce (always)**:
   - Small upward velocity (-150) on landing
   - Happens automatically, can't be disabled

2. **Manual Jump (while grounded)**:
   - Tap spacebar quickly = Normal jump (-500)
   - Hold spacebar for 0.5s+ = Super jump (-750)
   - Replaces the bounce with larger jump
   - Timer resets when you jump

3. **Auto-Jump Failsafe**:
   - If 2.0 seconds pass without jumping, force a normal jump
   - Prevents getting stuck on platform

**Benefits:**
- Player has full control
- Bounce feels natural (rubber ball)
- Clear difference between "let it bounce" and "jump manually"
- Auto-jump prevents getting stuck

---

### Option 3: Rhythm-Based System (Most Fun?)
**How it works:**
- Ball bounces automatically in rhythm
- Player times their spacebar press to boost height
- Think "rhythm game meets platformer"

**Implementation:**
1. **Automatic Rhythm Bouncing**:
   - Ball bounces every 1.5 seconds automatically
   - Base bounce height: -300 velocity
   - Visual bounce indicator (squash/stretch animation)

2. **Timing Boost**:
   - Green window: 0.2s before bounce happens
   - Yellow window: 0.1s before bounce happens
   - Perfect timing (green): +200 velocity boost → -500 total
   - Great timing (yellow): +450 velocity boost → -750 total
   - Early/late: No boost → -300 base bounce

3. **Visual Feedback**:
   - Timer ring around ball shows next bounce
   - Color changes in timing windows
   - Screen shake on perfect timing

**Benefits:**
- Skill-based gameplay
- Satisfying when you nail the timing
- Natural rhythm emerges
- Very arcade-like feel

---

## Recommended: Option 1 (Bounce-Based)

**Why:**
- Simplest to implement
- Easiest to understand for players
- Maintains rubber ball feel naturally
- Clear risk/reward (charge vs time)
- No timing required (accessibility)

**Code Structure:**
```gdscript
# Constants
const BOUNCE_MIN = -200.0       # No charge
const BOUNCE_NORMAL = -500.0    # Mid charge
const BOUNCE_MAX = -750.0       # Full charge
const CHARGE_TIME_MAX = 1.5     # Seconds to full charge
const AUTO_BOUNCE_TIME = 1.5    # Force bounce after this time

# State
var charge_time: float = 0.0
var grounded_time: float = 0.0

# Physics process
func _physics_process(delta):
    # ... gravity, movement, etc ...

    if is_grounded:
        grounded_time += delta

        # Charge if holding jump button
        if is_holding_jump:
            charge_time = min(charge_time + delta, CHARGE_TIME_MAX)

        # Auto-bounce after max time
        if grounded_time >= AUTO_BOUNCE_TIME:
            execute_bounce()

        # Release bounce when letting go
        if was_holding_jump and not is_holding_jump:
            execute_bounce()

    # ... rest of physics ...

func execute_bounce():
    # Calculate bounce height based on charge
    var charge_ratio = charge_time / CHARGE_TIME_MAX
    var bounce_velocity = lerp(BOUNCE_MIN, BOUNCE_MAX, charge_ratio)

    velocity.y = bounce_velocity
    is_grounded = false

    # Reset
    charge_time = 0.0
    grounded_time = 0.0

    # Stats
    if charge_ratio >= 0.8:
        GameManager.increment_forced_jump()  # Super jump

func on_landed():
    is_grounded = true
    # NO automatic bounce here - wait for charge/timer
```

**Visual Feedback Ideas:**
- Ball squashes down as charge increases
- Color shifts: Blue → White → Yellow (charge levels)
- Particle trail intensity based on jump height
- Screen shake on super bounces

---

## Which system do you prefer?

1. **Bounce-Based** (charge and release) - Simple, accessible
2. **Dual-Mode** (bounce + manual jump) - More control
3. **Rhythm-Based** (timing game) - Fun, skill-based

Or suggest modifications to any of these!
