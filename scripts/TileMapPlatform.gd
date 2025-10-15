extends Node2D
class_name TileMapPlatform

## Platform using TileMapLayer with built-in tileset physics
## The tileset already has physics polygons defined - we just use those!

# Platform types
enum PlatformType {
	STATIC,
	MOVING,
	BREAKABLE,
	TEMPORARY
}

@export var platform_type: PlatformType = PlatformType.STATIC
@export var middle_piece_count: int = 0  # 0-2 middle pieces

var platform_color: Color = Color.WHITE
var is_active: bool = true
var platform_width: float = 256.0  # Will be calculated based on tiles

# Node references
@onready var tilemap: TileMapLayer = $PlatformTiles

# Tile coordinates in the atlas
# Grass cloud platform pieces: (7,9), (7,10), (7,11)
const TILE_LEFT = Vector2i(7, 11)    # Left piece (rounded left edge)
const TILE_MIDDLE = Vector2i(7, 10)  # Middle piece
const TILE_RIGHT = Vector2i(7, 9)    # Right piece (rounded right edge)
const TILE_SIZE = 128

func _ready():
	# Groups are already set in scene
	add_to_group("platform")

	# Scale platform to 50% size
	scale = Vector2(0.5, 0.5)

	# Build platform from tiles
	setup_platform_tiles()

func setup_platform_tiles():
	"""Create platform using TileMapLayer with left, middle, and right pieces"""
	if not tilemap:
		push_error("TileMapLayer not found!")
		return

	# TileMap physics is ENABLED - uses collision polygons from tileset
	# Clear any existing tiles
	tilemap.clear()

	# Calculate total pieces (left + middles + right)
	var total_pieces = 2 + middle_piece_count
	platform_width = total_pieces * TILE_SIZE

	# Place tiles in a horizontal row starting at x=0
	# Tiles will be centered around platform's origin (0, 0)
	var start_x = -(total_pieces / 2)  # Start position to center the platform

	# Place LEFT tile
	tilemap.set_cell(Vector2i(start_x, 0), 0, TILE_LEFT)

	# Place MIDDLE tiles (0-2)
	for i in range(middle_piece_count):
		tilemap.set_cell(Vector2i(start_x + 1 + i, 0), 0, TILE_MIDDLE)

	# Place RIGHT tile
	tilemap.set_cell(Vector2i(start_x + 1 + middle_piece_count, 0), 0, TILE_RIGHT)

	# Physics collision is automatically handled by TileMapLayer!

func on_player_land():
	# Override in specific platform types
	pass

func deactivate():
	is_active = false
	queue_free()
