@tool
extends EditorScript

# Run this script via Tools > Execute Script in Godot Editor
# Generates individual AtlasTexture resources from the spritesheet XML

const SPRITESHEET_PATH = "res://assets/sprites/spritesheet-tiles-double.png"
const XML_PATH = "res://assets/sprites/spritesheet-tiles-double.xml"
const OUTPUT_DIR = "res://assets/sprites/atlas_tiles/"

func _run():
	print("=== Atlas Texture Generator ===")

	# Create output directory
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
		print("Created directory: ", OUTPUT_DIR)

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

	# Parse XML and create AtlasTextures
	var regex = RegEx.new()
	regex.compile('<SubTexture name="([^"]+)" x="(\\d+)" y="(\\d+)" width="(\\d+)" height="(\\d+)"')

	var matches = regex.search_all(xml_content)
	var created_count = 0

	for match_result in matches:
		var tile_name = match_result.get_string(1)
		var x = int(match_result.get_string(2))
		var y = int(match_result.get_string(3))
		var width = int(match_result.get_string(4))
		var height = int(match_result.get_string(5))

		# Create AtlasTexture
		var atlas = AtlasTexture.new()
		atlas.atlas = spritesheet
		atlas.region = Rect2(x, y, width, height)

		# Save as resource
		var output_path = OUTPUT_DIR + tile_name + ".tres"
		var result = ResourceSaver.save(atlas, output_path)

		if result == OK:
			created_count += 1
			if created_count % 50 == 0:
				print("Created %d atlas textures..." % created_count)
		else:
			printerr("Failed to save: ", output_path)

	print("=== Completed! ===")
	print("Created %d AtlasTexture resources in %s" % [created_count, OUTPUT_DIR])
	print("You can now use these in Sprite2D nodes or TileSets!")
