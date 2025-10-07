extends Node2D

# Scene references
var player: CharacterBody2D
var camera: Camera2D
var platform_spawner: Node2D
var ui: CanvasLayer

# Game state
var game_active: bool = false

func _ready():
	# Create background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1)  # Dark blue-black
	bg.size = Vector2(800, 1000)
	bg.z_index = -100
	add_child(bg)

	# Add CRT shader overlay
	add_crt_shader()

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

	# Create player
	player = CharacterBody2D.new()
	player.set_script(load("res://scripts/Player.gd"))
	player.position = Vector2(400, 800)
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

	# Start game
	start_game()

func start_game():
	game_active = true

	# Initialize GameManager session
	GameManager.start_game_session()

	# Spawn initial platforms
	platform_spawner.spawn_initial_platforms()

	# Start camera scrolling
	camera.start_scrolling()

func _process(delta):
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
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

func add_crt_shader():
	# Create a CanvasLayer for the CRT shader
	var crt_layer = CanvasLayer.new()
	crt_layer.layer = 100  # On top of everything
	add_child(crt_layer)

	# Create a ColorRect that covers the screen
	var crt_rect = ColorRect.new()
	crt_rect.size = Vector2(800, 1000)
	crt_rect.color = Color.WHITE

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
