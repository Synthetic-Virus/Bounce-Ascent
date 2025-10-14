@tool
extends EditorScript

# Run this script via Tools > Execute Script in Godot Editor
# Generates a TileSet resource from the spritesheet XML

const SPRITESHEET_PATH = "res://assets/sprites/spritesheet-tiles-double.png"
const XML_PATH = "res://assets/sprites/spritesheet-tiles-double.xml"
const OUTPUT_PATH = "res://assets/tilesets/platform_tileset.tres"

func _run():
	print("=== TileSet Generator ===")

	# Create tilesets directory
	if not DirAccess.dir_exists_absolute("res://assets/tilesets"):
		DirAccess.make_dir_recursive_absolute("res://assets/tilesets")

	# Load and parse XML
	var xml_file = FileAccess.open(XML_PATH, FileAccess.READ)
	if not xml_file:
		printerr("Failed to open XML file: ", XML_PATH)
		return

	var xml_content = xml_file.get_as_text()
	xml_file.close()

	# Load the base spritesheet
	var spritesheet = load(SPRITESHEET_PATH)
	if not spritesheet:
		printerr("Failed to load spritesheet: ", SPRITESHEET_PATH)
		return

	# Create TileSet
	var tileset = TileSet.new()

	# Add the spritesheet as an atlas source
	var atlas_source = TileSetAtlasSource.new()
	atlas_source.texture = spritesheet

	# Parse XML to get tile regions
	var regex = RegEx.new()
	regex.compile('<SubTexture name="([^"]+)" x="(\\d+)" y="(\\d+)" width="(\\d+)" height="(\\d+)"')

	var matches = regex.search_all(xml_content)
	var tile_count = 0

	# We'll organize tiles on a grid for easier management
	var tile_size = Vector2i(128, 128)
	atlas_source.texture_region_size = tile_size

	# Track which atlas coords we've used
	var used_coords = {}

	for match_result in matches:
		var tile_name = match_result.get_string(1)
		var x = int(match_result.get_string(2))
		var y = int(match_result.get_string(3))
		var width = int(match_result.get_string(4))
		var height = int(match_result.get_string(5))

		# Calculate grid coordinates
		var atlas_coord = Vector2i(x / 128, y / 128)

		# Skip if we've already added this coordinate
		if used_coords.has(atlas_coord):
			continue

		used_coords[atlas_coord] = tile_name

		# Create tile at this atlas coordinate
		atlas_source.create_tile(atlas_coord)

		# Add basic collision for platform-like tiles
		if tile_name.contains("terrain") or tile_name.contains("block") or tile_name.contains("brick"):
			var tile_data = atlas_source.get_tile_data(atlas_coord, 0)

			# Add physics layer if it doesn't exist
			if tileset.get_physics_layers_count() == 0:
				tileset.add_physics_layer()

			# Create a simple rectangular collision shape
			var polygon = PackedVector2Array([
				Vector2(0, 0),
				Vector2(128, 0),
				Vector2(128, 128),
				Vector2(0, 128)
			])
			tile_data.set_collision_polygons_count(0, 1)
			tile_data.set_collision_polygon_points(0, 0, polygon)

		tile_count += 1
		if tile_count % 50 == 0:
			print("Processed %d tiles..." % tile_count)

	# Add the atlas source to the tileset
	tileset.add_source(atlas_source, 0)

	# Save the tileset
	var result = ResourceSaver.save(tileset, OUTPUT_PATH)

	if result == OK:
		print("=== Completed! ===")
		print("Created TileSet with %d tiles at: %s" % [tile_count, OUTPUT_PATH])
		print("Platform-like tiles have automatic collision shapes!")
		print("\nTo use:")
		print("1. Add a TileMapLayer node to your scene")
		print("2. Set its TileSet property to: %s" % OUTPUT_PATH)
		print("3. Start painting tiles!")
	else:
		printerr("Failed to save TileSet: ", OUTPUT_PATH)
