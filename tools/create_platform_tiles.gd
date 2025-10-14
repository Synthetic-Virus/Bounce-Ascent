@tool
extends EditorScript

# Creates platform tile resources for positions (7,9), (7,10), (7,11)

func _run():
	print("=== Creating Platform Tiles ===")

	# Create resources directory if needed
	if not DirAccess.dir_exists_absolute("res://resources"):
		DirAccess.make_dir_recursive_absolute("res://resources")

	var spritesheet = load("res://assets/sprites/spritesheet-tiles-double.png")
	if not spritesheet:
		printerr("Failed to load spritesheet")
		return

	# Tile position (7, 9) = pixel (896, 1152) - LEFT piece
	var left_tile = AtlasTexture.new()
	left_tile.atlas = spritesheet
	left_tile.region = Rect2(896, 1152, 128, 128)
	ResourceSaver.save(left_tile, "res://resources/platform_left.tres")
	print("✓ Created platform_left.tres")

	# Tile position (7, 10) = pixel (896, 1280) - MIDDLE piece
	var middle_tile = AtlasTexture.new()
	middle_tile.atlas = spritesheet
	middle_tile.region = Rect2(896, 1280, 128, 128)
	ResourceSaver.save(middle_tile, "res://resources/platform_middle.tres")
	print("✓ Created platform_middle.tres")

	# Tile position (7, 11) = pixel (896, 1408) - RIGHT piece
	var right_tile = AtlasTexture.new()
	right_tile.atlas = spritesheet
	right_tile.region = Rect2(896, 1408, 128, 128)
	ResourceSaver.save(right_tile, "res://resources/platform_right.tres")
	print("✓ Created platform_right.tres")

	print("\n=== Success! ===")
	print("Platform tile resources created in res://resources/")
