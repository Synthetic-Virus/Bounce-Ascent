extends Node2D

# Scene references
var player: CharacterBody2D
var camera: Camera2D
var platform_spawner: Node2D
var ui: CanvasLayer
var countdown_label: Label

# Game state
var game_active: bool = false
var countdown_active: bool = false
var countdown_time: float = 3.0

func _ready():
	# Create dynamic background that transitions from sky to space
	var bg = ColorRect.new()
	bg.color = Color(0.53, 0.81, 0.92)  # Sky blue
	bg.size = Vector2(800, 1000)
	bg.z_index = -100
	bg.set_script(preload("res://scripts/DynamicBackground.gd"))
	add_child(bg)

	# Add CRT shader overlay (disabled for now - causes white screen)
	# add_crt_shader()

	# Create camera
	camera = Camera2D.new()
	camera.set_script(load("res://scripts/GameCamera.gd"))
	camera.position = Vector2(400, 500)
	add_child(camera)

	# Create platform spawner
	platform_spawner = Node2D.new()
	platform_spawner.set_script(load("res://scripts/PlatformSpawner.gd"))
	add_child(platform_spawner)
	platform_spawner.set_camera(camera)

	# Create player (position closer to camera center for better start)
	player = CharacterBody2D.new()
	player.set_script(load("res://scripts/Player.gd"))
	player.position = Vector2(400, 400)  # Higher up, closer to camera
	add_child(player)

	# Create UI
	ui = CanvasLayer.new()
	ui.set_script(load("res://scripts/GameUI.gd"))
	add_child(ui)

	# Connect signals
	camera.player_fell_behind.connect(_on_player_fell_behind)
	player.landed_on_platform.connect(_on_player_landed)

	# Set player camera reference
	camera.set_player(player)

	# Create countdown label
	create_countdown_label()

	# Start countdown instead of immediate game
	start_countdown()

func start_game():
	game_active = true

	# Initialize GameManager session
	GameManager.start_game_session()

	# Enable player physics now that game is starting
	player.enable_physics()

	# Start camera scrolling (platforms already spawned during countdown)
	camera.start_scrolling()

func create_countdown_label():
	countdown_label = Label.new()
	countdown_label.add_theme_font_size_override("font_size", 120)
	countdown_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.position = Vector2(300, 400)
	countdown_label.size = Vector2(200, 200)
	countdown_label.z_index = 200
	countdown_label.visible = false
	add_child(countdown_label)

func start_countdown():
	countdown_active = true
	countdown_time = 3.0
	countdown_label.visible = true

	# Spawn platforms but don't start scrolling yet
	platform_spawner.spawn_initial_platforms()

func _process(delta):
	# Handle countdown
	if countdown_active:
		countdown_time -= delta
		if countdown_time > 0:
			countdown_label.text = str(int(ceil(countdown_time)))
		else:
			countdown_label.text = "GO!"
			if countdown_time < -0.5:  # Show GO! for 0.5 seconds
				countdown_label.visible = false
				countdown_active = false
				start_game()
		return

	if not game_active:
		return

	# Update time survived
	GameManager.update_time_survived(delta)

	# Update height based on camera position
	var current_height = camera.get_current_height()
	if current_height > GameManager.session_stats.height:
		var height_diff = current_height - GameManager.session_stats.height
		for i in range(height_diff):
			GameManager.increment_height()

func _on_player_fell_behind():
	if game_active:
		end_game("fell")

func _on_player_landed(platform):
	# Platform already increments stats via GameManager
	pass

func end_game(death_type: String):
	game_active = false
	camera.stop_scrolling()

	# End session and save
	GameManager.end_game_session(death_type)

	# Show game over screen
	await get_tree().create_timer(1.0).timeout
	show_game_over_screen()

func show_game_over_screen():
	# Store stats in GameManager for GameOver scene to access
	var game_over_scene = load("res://scenes/GameOver.tscn").instantiate()
	game_over_scene.stats = GameManager.session_stats.duplicate()
	get_tree().root.add_child(game_over_scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = game_over_scene

func add_crt_shader():
	# Create a CanvasLayer for the CRT shader
	var crt_layer = CanvasLayer.new()
	crt_layer.layer = 100  # On top of everything
	add_child(crt_layer)

	# Create a ColorRect that covers the screen
	var crt_rect = ColorRect.new()
	crt_rect.size = Vector2(800, 1000)
	crt_rect.color = Color(1.0, 1.0, 1.0, 0.0)  # Transparent white
	crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse

	# Load and apply the CRT shader
	var shader = load("res://resources/shaders/crt_shader.gdshader")
	if shader:
		var material = ShaderMaterial.new()
		material.shader = shader
		crt_rect.material = material

	crt_layer.add_child(crt_rect)

func _input(event):
	# ESC to quit
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
