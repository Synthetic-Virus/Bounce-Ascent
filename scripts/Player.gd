extends CharacterBody2D

# Player physics constants
const MOVE_SPEED = 300.0
const JUMP_VELOCITY = -500.0
const AUTO_JUMP_INTERVAL = 2.5  # Seconds between auto jumps
const MANUAL_JUMP_COOLDOWN = 0.3  # Cooldown between manual jumps

# State variables
var auto_jump_timer: float = 0.0
var manual_jump_cooldown_timer: float = 0.0
var is_grounded: bool = false
var can_jump: bool = true
var last_platform = null
var physics_enabled: bool = false  # Don't move until countdown finishes

# Screen boundaries
var screen_width: int = 800
var player_radius: float = 16.0

# Customization
var ball_color: Color = Color(0.29, 0.62, 1.0)

# Signals
signal landed_on_platform(platform)
signal attempted_edge_escape()
signal jumped(is_manual: bool)

func _ready():
	# Get ball color from GameManager
	ball_color = GameManager.get_ball_color()

	# Set up collision shape
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = player_radius
	collision.shape = circle
	add_child(collision)

	# Visual representation
	queue_redraw()

func _draw():
	# Draw ball with custom color
	draw_circle(Vector2.ZERO, player_radius, ball_color)
	draw_arc(Vector2.ZERO, player_radius, 0, TAU, 32, ball_color.lightened(0.3), 2.0)

func _physics_process(delta):
	# Don't process physics until game starts
	if not physics_enabled:
		velocity = Vector2.ZERO
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
		is_grounded = false
	else:
		if not is_grounded:
			on_landed()
		is_grounded = true

	# Horizontal movement
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * MOVE_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED * delta * 3)

	# Clamp to screen boundaries (prevent going off screen)
	var future_x = position.x + velocity.x * delta
	if future_x - player_radius < 0 or future_x + player_radius > screen_width:
		velocity.x = 0
		# Track edge escape attempts
		if abs(direction) > 0:
			attempted_edge_escape.emit()
			GameManager.increment_edge_escape()

	# Auto-jump timer
	if is_grounded:
		auto_jump_timer += delta
		if auto_jump_timer >= AUTO_JUMP_INTERVAL:
			perform_jump(false)
			auto_jump_timer = 0.0

	# Manual jump cooldown
	if manual_jump_cooldown_timer > 0:
		manual_jump_cooldown_timer -= delta

	# Manual jump input
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
		if is_grounded and manual_jump_cooldown_timer <= 0:
			perform_jump(true)
			manual_jump_cooldown_timer = MANUAL_JUMP_COOLDOWN
			GameManager.increment_forced_jump()

	move_and_slide()

	# Clamp position to screen (hard boundary)
	position.x = clamp(position.x, player_radius, screen_width - player_radius)

func perform_jump(is_manual: bool):
	velocity.y = JUMP_VELOCITY
	jumped.emit(is_manual)

func on_landed():
	is_grounded = true

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
	auto_jump_timer = 0.0
	manual_jump_cooldown_timer = 0.0
	is_grounded = false
	last_platform = null
	physics_enabled = false

func enable_physics():
	physics_enabled = true

func get_gravity() -> Vector2:
	return Vector2(0, ProjectSettings.get_setting("physics/2d/default_gravity"))
