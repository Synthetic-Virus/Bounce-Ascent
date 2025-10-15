extends Node2D

# Scene references
var player: CharacterBody2D
var camera: Camera2D
var platform_spawner: Node2D
var ui: CanvasLayer
# Game state
var game_active: bool = false

var background: ColorRect

func _ready():
	# Create dynamic background that transitions from sky to space
	background = ColorRect.new()
	background.color = Color(0.53, 0.81, 0.92)  # Sky blue
	background.size = Vector2(800, 1000)
	background.position = Vector2(0, 0)  # Explicitly set to viewport origin
	background.z_index = -100
	background.set_script(preload("res://scripts/DynamicBackground.gd"))
	add_child(background)

	# Add CRT shader overlay (disabled for now - causes white screen)
	# add_crt_shader()

	# Create camera (start at bottom near player)
	var camera_scene = load("res://scenes/camera/GameCamera.tscn")
	camera = camera_scene.instantiate()
	camera.position = Vector2(400, 900)  # Start near bottom with player
	add_child(camera)

	# Create platform spawner
	platform_spawner = Node2D.new()
	platform_spawner.set_script(load("res://scripts/PlatformSpawner.gd"))
	add_child(platform_spawner)
	platform_spawner.set_camera(camera)

	# Create player (start at bottom on ground for seamless transition)
	var player_scene = load("res://scenes/player/Player.tscn")
	player = player_scene.instantiate()
	player.position = Vector2(400, 800)  # On top of Ground scene collision
	add_child(player)

	# Create UI
	ui = CanvasLayer.new()
	ui.set_script(load("res://scripts/GameUI.gd"))
	add_child(ui)

	# Set player reference for rhythm indicator (AFTER add_child so _ready has run)
	ui.set_player_reference(player)

	# Connect signals
	camera.player_fell_behind.connect(_on_player_fell_behind)
	player.landed_on_platform.connect(_on_player_landed)

	# Set player camera reference
	camera.set_player(player)

	# Setup background with camera reference
	background.setup_background(camera)

	# Spawn platforms and start game immediately
	platform_spawner.spawn_initial_platforms()
	start_game()

func start_game():
	game_active = true

	# Initialize GameManager session
	GameManager.start_game_session()

	# Enable player physics now that game is starting
	player.enable_physics()

	# Start camera scrolling immediately
	camera.start_scrolling()

func _process(delta):
	if not game_active:
		return

	# Update time survived
	GameManager.update_time_survived(delta)

	# Update height based on player's actual position (how high they've climbed)
	# Player starts at y=400, moving upward (negative Y) increases height
	var player_height = max(0, int((400.0 - player.position.y) / 10.0))

	# Update GameManager if player reached new height
	if player_height > GameManager.session_stats.height:
		var height_diff = player_height - GameManager.session_stats.height
		for i in range(height_diff):
			GameManager.increment_height()

func _on_player_fell_behind():
	if game_active:
		end_game("fell")

func _on_player_landed(_platform):
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
		var shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		crt_rect.material = shader_material

	crt_layer.add_child(crt_rect)

func _input(event):
	# ESC to quit
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
