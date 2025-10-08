extends CharacterBody2D

# Player physics constants
const MOVE_SPEED = 300.0

# Rhythm-based bounce system
const BOUNCE_BASE = -300.0          # Base automatic bounce
const BOUNCE_PERFECT = -500.0       # Perfect timing (green window)
const BOUNCE_GREAT = -750.0         # Great timing (yellow window)
const BOUNCE_INTERVAL = 1.5         # Rhythm interval in seconds (gets faster with combo)
const TIMING_WINDOW_PERFECT = 0.2   # Perfect window (green) - 0.2s before bounce
const TIMING_WINDOW_GREAT = 0.1     # Great window (yellow) - 0.1s before bounce
const COMBO_INTERVAL_REDUCTION = 0.1  # Reduce interval by this much per combo
const MIN_BOUNCE_INTERVAL = 0.5     # Minimum interval (max speed)
const COMBO_VELOCITY_BONUS = -50.0  # Extra velocity per combo level

# State variables
var bounce_timer: float = 0.0
var is_grounded: bool = false
var last_platform = null
var physics_enabled: bool = false  # Don't move until countdown finishes
var is_touching_edge: bool = false  # Track if already counted edge escape
var just_pressed_jump: bool = false  # Track jump input for timing
var last_bounce_quality: String = ""  # "perfect", "great", or "base"
var feedback_timer: float = 0.0  # Timer for visual feedback effects
var feedback_scale: float = 1.0  # Scale effect for feedback
var combo_level: int = 0  # Track successive good bounces
var current_bounce_interval: float = BOUNCE_INTERVAL  # Dynamic interval

# Screen boundaries
var screen_width: int = 800
var player_radius: float = 16.0

# Customization
var ball_color: Color = Color(0.29, 0.62, 1.0)

# Signals
signal landed_on_platform(platform)
signal attempted_edge_escape()
signal jumped(quality: String)

func _ready():
	# Get ball color from GameManager
	ball_color = GameManager.get_ball_color()

	# Set up collision shape
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = player_radius
	collision.shape = circle
	add_child(collision)

	# Set z_index for proper layering
	z_index = 10

	# Visual representation
	queue_redraw()

func _draw():
	# Ensure feedback_scale is valid
	if feedback_scale <= 0 or is_nan(feedback_scale):
		feedback_scale = 1.0

	# Apply scale effect for feedback
	var draw_radius = player_radius * feedback_scale

	# Draw black outline/shadow first
	var outline_width = 3.0
	draw_circle(Vector2.ZERO, draw_radius + outline_width, Color.BLACK)

	# Draw ball with custom color
	draw_circle(Vector2.ZERO, draw_radius, ball_color)

	# Add rubber texture - simple geometric lines
	var darker = ball_color.darkened(0.2)
	var lighter = ball_color.lightened(0.3)

	# Draw curved lines for rubber pattern
	for i in range(3):
		var angle = (i * TAU / 3.0)
		var start = Vector2(cos(angle), sin(angle)) * (draw_radius * 0.7)
		var end = Vector2(cos(angle + PI), sin(angle + PI)) * (draw_radius * 0.7)
		draw_line(start, end, darker, 2.0)

	# Highlight circle for shine
	draw_circle(Vector2(-4, -4), draw_radius * 0.3, Color(lighter, 0.4))

	# Outer rim
	draw_arc(Vector2.ZERO, draw_radius, 0, TAU, 32, lighter, 2.0)

	# Draw quality feedback burst
	if feedback_timer > 0 and (last_bounce_quality == "great" or last_bounce_quality == "perfect"):
		var text_color = Color.YELLOW if last_bounce_quality == "great" else Color.GREEN
		var burst_radius = draw_radius + 10 + (feedback_timer * 30)
		draw_arc(Vector2.ZERO, burst_radius, 0, TAU, 32, text_color, 3.0)

	# RHYTHM TIMING INDICATOR - Draw timer ring around ball
	if is_grounded and physics_enabled:
		var time_until_bounce = current_bounce_interval - bounce_timer
		var progress = bounce_timer / current_bounce_interval

		# Determine ring color based on timing window
		var ring_color = Color.WHITE
		var ring_width = 3.0

		if time_until_bounce <= TIMING_WINDOW_GREAT:
			# GREAT window (yellow)
			ring_color = Color.YELLOW
			ring_width = 5.0
		elif time_until_bounce <= TIMING_WINDOW_PERFECT:
			# PERFECT window (green)
			ring_color = Color.GREEN
			ring_width = 4.0

		# Draw progress ring
		var ring_radius = player_radius + 8.0
		var arc_angle = progress * TAU
		draw_arc(Vector2.ZERO, ring_radius, -PI/2, -PI/2 + arc_angle, 32, ring_color, ring_width)

		# Draw timing window indicators
		if time_until_bounce > TIMING_WINDOW_PERFECT:
			# Draw green window marker
			var green_start_angle = -PI/2 + ((current_bounce_interval - TIMING_WINDOW_PERFECT) / current_bounce_interval) * TAU
			draw_arc(Vector2.ZERO, ring_radius + 3, green_start_angle, green_start_angle + 0.1, 8, Color.GREEN, 2.0)

		if time_until_bounce > TIMING_WINDOW_GREAT:
			# Draw yellow window marker
			var yellow_start_angle = -PI/2 + ((current_bounce_interval - TIMING_WINDOW_GREAT) / current_bounce_interval) * TAU
			draw_arc(Vector2.ZERO, ring_radius + 3, yellow_start_angle, yellow_start_angle + 0.1, 8, Color.YELLOW, 2.0)

	# Draw combo counter inside the ball
	if combo_level > 0:
		var combo_text = str(combo_level)
		draw_string(ThemeDB.fallback_font, Vector2(-8, 8), combo_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.WHITE)

func _physics_process(delta):
	# Don't process physics until game starts
	if not physics_enabled:
		velocity = Vector2.ZERO
		return

	# Decay feedback effects
	if feedback_timer > 0:
		feedback_timer -= delta
		feedback_scale = lerp(feedback_scale, 1.0, delta * 5.0)
		queue_redraw()

	# Apply gravity (only when not on floor)
	if not is_on_floor():
		velocity.y += _get_gravity().y * delta
		is_grounded = false
	else:
		# Just landed
		if not is_grounded:
			on_landed()
		is_grounded = true

		# Stop gravity from pulling down while grounded
		if velocity.y > 0:
			velocity.y = 0

	# Horizontal movement (explicit key checks)
	var direction = 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		direction = -1.0
	elif Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		direction = 1.0

	if direction != 0:
		velocity.x = direction * MOVE_SPEED
	else:
		# Stop much faster when no input (reduce sliding)
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED * delta * 10)

	# Clamp to screen boundaries (prevent going off screen)
	var future_x = position.x + velocity.x * delta
	if future_x - player_radius < 0 or future_x + player_radius > screen_width:
		velocity.x = 0
		# Track edge escape attempts (only count once per contact)
		if abs(direction) > 0 and not is_touching_edge:
			attempted_edge_escape.emit()
			GameManager.increment_edge_escape()
			is_touching_edge = true
	else:
		# Reset flag when away from edge
		is_touching_edge = false

	# Detect jump button press (not hold - we want the moment of press)
	var jump_just_pressed = Input.is_action_just_pressed("ui_accept") or \
		(Input.is_physical_key_pressed(KEY_SPACE) and not just_pressed_jump) or \
		(Input.is_physical_key_pressed(KEY_W) and not just_pressed_jump) or \
		(Input.is_physical_key_pressed(KEY_UP) and not just_pressed_jump)

	just_pressed_jump = Input.is_physical_key_pressed(KEY_SPACE) or \
		Input.is_physical_key_pressed(KEY_W) or \
		Input.is_physical_key_pressed(KEY_UP)

	# RHYTHM-BASED BOUNCE SYSTEM WITH COMBO
	if is_grounded:
		bounce_timer += delta
		queue_redraw()  # Redraw to update timing ring

		# Check timing window
		var time_until_bounce = current_bounce_interval - bounce_timer
		var in_perfect_window = time_until_bounce <= TIMING_WINDOW_PERFECT and time_until_bounce > TIMING_WINDOW_GREAT
		var in_great_window = time_until_bounce <= TIMING_WINDOW_GREAT and time_until_bounce > 0

		# Player pressed jump - check timing
		if jump_just_pressed:
			if in_great_window:
				# GREAT timing! (yellow window) - increase combo
				combo_level += 1
				execute_bounce(BOUNCE_GREAT + (combo_level * COMBO_VELOCITY_BONUS), "great")
				update_bounce_interval()
			elif in_perfect_window:
				# PERFECT timing! (green window) - increase combo
				combo_level += 1
				execute_bounce(BOUNCE_PERFECT + (combo_level * COMBO_VELOCITY_BONUS), "perfect")
				update_bounce_interval()
			else:
				# Early or late - reset combo
				combo_level = 0
				current_bounce_interval = BOUNCE_INTERVAL
				execute_bounce(BOUNCE_BASE, "early")

		# Auto-bounce when timer expires - reset combo
		elif bounce_timer >= current_bounce_interval:
			combo_level = 0
			current_bounce_interval = BOUNCE_INTERVAL
			execute_bounce(BOUNCE_BASE, "base")

	move_and_slide()

	# Clamp position to screen (hard boundary)
	position.x = clamp(position.x, player_radius, screen_width - player_radius)

func update_bounce_interval():
	"""Update bounce interval based on combo level"""
	current_bounce_interval = max(
		MIN_BOUNCE_INTERVAL,
		BOUNCE_INTERVAL - (combo_level * COMBO_INTERVAL_REDUCTION)
	)

func execute_bounce(bounce_velocity: float, quality: String):
	"""Execute a bounce with the given velocity and quality rating"""
	if is_grounded:
		velocity.y = bounce_velocity
		is_grounded = false
		bounce_timer = 0.0
		last_bounce_quality = quality

		# Emit jump signal with quality
		jumped.emit(quality)

		# Visual feedback based on quality (stronger with combo)
		if quality == "great":
			feedback_timer = 0.3
			feedback_scale = 1.3 + (combo_level * 0.1)
		elif quality == "perfect":
			feedback_timer = 0.2
			feedback_scale = 1.15 + (combo_level * 0.05)

		queue_redraw()

func on_landed():
	is_grounded = true

	# Reset bounce timer for new landing (don't reset combo here)
	bounce_timer = 0.0

	# Check what we landed on
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider.is_in_group("platform"):
			if collider != last_platform:
				last_platform = collider
				landed_on_platform.emit(collider)
				GameManager.increment_platform_landed()

				# Handle platform-specific behavior
				if collider.has_method("on_player_land"):
					collider.on_player_land()

func reset_position(spawn_position: Vector2):
	position = spawn_position
	velocity = Vector2.ZERO
	bounce_timer = 0.0
	is_grounded = false
	last_platform = null
	physics_enabled = false
	combo_level = 0
	current_bounce_interval = BOUNCE_INTERVAL

func enable_physics():
	physics_enabled = true

func _get_gravity() -> Vector2:
	return Vector2(0, ProjectSettings.get_setting("physics/2d/default_gravity"))
