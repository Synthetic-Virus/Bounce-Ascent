@tool
extends EditorScript

# Run this via Tools > Execute Script to create the coin animation scene

func _run():
	print("=== Creating Coin Animation ===")

	# Load the spritesheet
	var spritesheet = load("res://assets/sprites/spritesheet-tiles-double.png")
	if not spritesheet:
		printerr("Failed to load spritesheet")
		return

	# Create atlas textures for the two coin frames
	# Tile position (15, 8) = pixel (1920, 1024)
	var frame1 = AtlasTexture.new()
	frame1.atlas = spritesheet
	frame1.region = Rect2(1920, 1024, 128, 128)

	# Tile position (15, 9) = pixel (1920, 1152)
	var frame2 = AtlasTexture.new()
	frame2.atlas = spritesheet
	frame2.region = Rect2(1920, 1152, 128, 128)

	# Create SpriteFrames resource
	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation("rotate")
	sprite_frames.set_animation_loop("rotate", true)
	sprite_frames.set_animation_speed("rotate", 2.0)  # 2 FPS for slow rotation

	sprite_frames.add_frame("rotate", frame1, 1.0, 0)
	sprite_frames.add_frame("rotate", frame2, 1.0, 1)

	# Save the SpriteFrames resource
	var sprite_frames_path = "res://resources/coin_animation.tres"
	var result = ResourceSaver.save(sprite_frames, sprite_frames_path)

	if result != OK:
		printerr("Failed to save SpriteFrames resource")
		return

	print("✓ Created SpriteFrames: ", sprite_frames_path)

	# Create the scene
	var coin_node = AnimatedSprite2D.new()
	coin_node.name = "Coin"
	coin_node.sprite_frames = sprite_frames
	coin_node.animation = "rotate"
	coin_node.autoplay = "rotate"

	# Create packed scene
	var packed_scene = PackedScene.new()
	packed_scene.pack(coin_node)

	# Save the scene
	var scene_path = "res://scenes/Coin.tscn"
	result = ResourceSaver.save(packed_scene, scene_path)

	if result == OK:
		print("✓ Created scene: ", scene_path)
		print("\n=== Success! ===")
		print("The coin animation is ready to use.")
		print("Open scenes/Coin.tscn to see it in action!")
	else:
		printerr("Failed to save scene")
