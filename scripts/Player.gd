extends CharacterBody2D

# Player physics constants
const MOVE_SPEED = 300.0
const GRAVITY = 980.0

# Mario-style super jump system
const JUMP_NORMAL = -500.0        # Normal jump
const JUMP_SUPER = -900.0         # Super jump (timed with landing)
const JUMP_COMBO_BONUS = -100.0   # Extra velocity per combo level
const LANDING_WINDOW = 0.15       # Time window after landing to press jump for super jump (150ms)

# State variables
var is_grounded: bool = false
var last_platform = null
var physics_enabled: bool = false  # Don't move until countdown finishes
var is_touching_edge: bool = false
var time_since_landing: float = 0.0  # Track time since last landing
var can_super_jump: bool = false     # True during landing window
var combo_level: int = 0             # Track successive super jumps
var jump_was_pressed: bool = false   # Track previous frame's jump button state

# Screen boundaries
var screen_width: int = 800
var player_radius: float = 72.0  # Increased by 50% from 48px

# Customization
var ball_color: Color = Color(0.29, 0.62, 1.0)

# Sprite
@onready var ball_sprite: AnimatedSprite2D = $BallSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var combo_label: Label = $ComboLabel

# Signals
signal landed_on_platform(platform)
signal attempted_edge_escape()
signal jumped(quality: String)

func _ready():
	# Get ball color from GameManager
	ball_color = GameManager.get_ball_color()

	# Apply ball color to sprite
	ball_sprite.modulate = ball_color

	# Scale sprite to match player radius (128x128 sprite frames → 144px diameter = 72px radius)
	# Increased by 50% from previous 96px
	const SPRITE_SIZE: float = 128.0
	const PLAYER_DIAMETER: float = 144.0
	const SPRITE_SCALE: float = PLAYER_DIAMETER / SPRITE_SIZE
	ball_sprite.scale = Vector2.ONE * SPRITE_SCALE

	# Start with idle animation
	ball_sprite.play("idle")

	# Set z_index for proper layering
	z_index = 10

	# Hide combo label initially
	combo_label.visible = false

func _physics_process(delta):
	# Don't process physics until game starts
	if not physics_enabled:
		velocity = Vector2.ZERO
		return

	# Track landing window timing
	if can_super_jump:
		time_since_landing += delta
		if time_since_landing > LANDING_WINDOW:
			can_super_jump = false

	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		is_grounded = false
		# Play idle animation when in mid-air (if not already playing jump animation)
		if ball_sprite.animation != "jump" and ball_sprite.animation != "idle":
			ball_sprite.play("idle")
	else:
		# Just landed
		if not is_grounded:
			on_landed()
		is_grounded = true

		# Stop downward velocity while grounded
		if velocity.y > 0:
			velocity.y = 0

	# Horizontal movement
	var direction = 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		direction = -1.0
	elif Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		direction = 1.0

	if direction != 0:
		velocity.x = direction * MOVE_SPEED
	else:
		# Stop quickly when no input
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED * delta * 10)

	# Screen boundaries
	var future_x = position.x + velocity.x * delta
	if future_x - player_radius < 0 or future_x + player_radius > screen_width:
		velocity.x = 0
		if abs(direction) > 0 and not is_touching_edge:
			attempted_edge_escape.emit()
			GameManager.increment_edge_escape()
			is_touching_edge = true
	else:
		is_touching_edge = false

	# Jump input - detect if button is currently pressed
	var jump_is_pressed = Input.is_action_pressed("ui_accept") or \
		Input.is_key_pressed(KEY_SPACE) or \
		Input.is_key_pressed(KEY_W) or \
		Input.is_key_pressed(KEY_UP)

	# Detect "just pressed" - button is pressed now but wasn't last frame
	var jump_just_pressed = jump_is_pressed and not jump_was_pressed
	jump_was_pressed = jump_is_pressed

	# Mario-style super jump: press jump during landing window
	if is_grounded and jump_just_pressed:
		if can_super_jump:
			# SUPER JUMP! Timed correctly with landing
			combo_level += 1
			# Each combo adds extra height
			var jump_velocity = JUMP_SUPER + (combo_level * JUMP_COMBO_BONUS)
			execute_jump(jump_velocity, "super")
			can_super_jump = false
		else:
			# Normal jump
			combo_level = 0
			execute_jump(JUMP_NORMAL, "normal")

	move_and_slide()

	# Clamp position to screen
	position.x = clamp(position.x, player_radius, screen_width - player_radius)

	# Update combo label
	if combo_level > 0:
		combo_label.text = str(combo_level)
		combo_label.visible = true
	else:
		combo_label.visible = false

func execute_jump(jump_velocity: float, quality: String):
	"""Execute a jump with the given velocity"""
	if is_grounded:
		velocity.y = jump_velocity
		is_grounded = false

		# Play jump animation
		ball_sprite.play("jump")

		# Emit jump signal
		jumped.emit(quality)

func on_landed():
	"""Called when player lands on a platform"""
	is_grounded = true
	time_since_landing = 0.0
	can_super_jump = true  # Enable super jump window

	# Play landing animation
	ball_sprite.play("landing")

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
	"""Reset player to starting position"""
	position = spawn_position
	velocity = Vector2.ZERO
	is_grounded = false
	last_platform = null
	physics_enabled = false
	combo_level = 0
	can_super_jump = false
	time_since_landing = 0.0
	jump_was_pressed = false

func enable_physics():
	"""Enable physics processing (called after countdown)"""
	physics_enabled = true

func _get_gravity() -> Vector2:
	return Vector2(0, GRAVITY)
