# TileSet Usage Guide

## Bounce Ascent Tile Implementation

Bounce Ascent uses the Kenney platformer pack (128×128 tiles) for modular platform generation. This guide explains the implementation and how to work with the tiles.

## Understanding the Tile Borders

The tiles you're seeing with borders are **not broken** - this is the intentional artistic style! The Kenney platformer pack uses beveled edges to give tiles a 3D appearance.

## Best Tiles for Simple Platforms

### **Option 1: Simple Block Tiles (Recommended for Beginners)**
These are flat, clean platforms without complex terrain connections:

- `block_blue` - Simple blue platform block
- `block_green` - Simple green platform block
- `block_red` - Simple red platform block
- `block_yellow` - Simple yellow platform block
- `block_plank` - Wooden plank platform
- `block_planks` - Multi-plank platform

**These are perfect for your Bounce Ascent game!** They work standalone without needing adjacent tiles.

### **Option 2: Terrain Tiles (For Connected Platforms)**
These need to be used in combinations to look correct:

#### Grass Terrain Example:
```
terrain_grass_block_top_left  | terrain_grass_block_top  | terrain_grass_block_top_right
terrain_grass_block_left      | terrain_grass_block_center| terrain_grass_block_right
terrain_grass_block_bottom_left| terrain_grass_block_bottom| terrain_grass_block_bottom_right
```

When you connect them properly, the borders align and create seamless terrain.

### **Option 3: Cloud Platforms (Floating Platforms)**
These are designed to be standalone floating platforms:

- `terrain_grass_cloud` - Grass floating platform
- `terrain_dirt_cloud` - Dirt floating platform
- `terrain_stone_cloud` - Stone floating platform
- `terrain_snow_cloud` - Snow floating platform

## How to Use in Godot

1. **Open the TileMap palette** (click TileMapLayer node, then "TileMap" tab at bottom)
2. **Use the search bar** in the palette to filter:
   - Search "block_" for simple blocks
   - Search "cloud" for floating platforms
   - Search "terrain_grass" for grass terrain sets
3. **Paint your level!**

## Current Bounce Ascent Implementation

### Platform Tiles Used (v0.1.1+)

Bounce Ascent uses three specific grass terrain tiles for modular platform generation:

- **Left Edge**: Tile (7,11) at position (896, 1408) - Rounded left edge
- **Middle Piece**: Tile (7,10) at position (896, 1280) - Flat middle section
- **Right Edge**: Tile (7,9) at position (896, 1152) - Rounded right edge

### How Platforms Are Built

Each platform is dynamically assembled at runtime:

```
Platform Width = (2 + middle_count) × 128px

Examples:
- 0 middle pieces: [LEFT][RIGHT] = 256px
- 1 middle piece: [LEFT][MIDDLE][RIGHT] = 384px
- 2 middle pieces: [LEFT][MIDDLE][MIDDLE][RIGHT] = 512px
```

The `middle_count` is randomized (0-2) for each platform, creating natural width variation.

### Collision System

Platforms use **thin collision boxes** (20px height) positioned at the visual top of the grass:

```gdscript
collision.shape.size = Vector2(total_width, 20)
collision.position = Vector2(0, -54)  # Top surface only
```

This prevents the ball from getting stuck inside platforms while ensuring proper landing detection.

### Ground Row

The ground uses only middle tiles in a continuous row across the screen width:

```
[MIDDLE][MIDDLE][MIDDLE][MIDDLE][MIDDLE][MIDDLE]...
```

This creates a seamless grass surface at the bottom of the play area.

## Technical Details

### Atlas Texture Extraction

```gdscript
var atlas = AtlasTexture.new()
atlas.atlas = load("res://assets/sprites/spritesheet-tiles-double.png")
atlas.region = Rect2(896, 1280, 128, 128)  # Middle tile
```

### Sprite Creation

```gdscript
var sprite = Sprite2D.new()
sprite.texture = atlas
sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # Pixel perfect
sprite.position = Vector2(x_offset, 0)
add_child(sprite)
```

### Camera Adjustments

Because tiles are 128×128 (larger than typical pixel art), the camera uses:
- **Zoom**: 0.6× (shows more area)
- **Scroll Speed**: 25 px/s (slower base speed)
- **Platform Spacing**: 180px vertical gap

## File Locations

- **Spritesheet**: `assets/sprites/spritesheet-tiles-double.png`
- **XML Atlas**: `assets/sprites/spritesheet-tiles-double.xml`
- **Platform Script**: `scripts/Platform.gd` (see `setup_modular_platform()`)
- **Spawner Script**: `scripts/PlatformSpawner.gd` (see `create_ground_row()`)

## Extending the System

To add new platform tile types:

1. Choose tiles from the spritesheet (positions in XML)
2. Create AtlasTexture regions in your platform variant script
3. Set `texture_filter = TEXTURE_FILTER_NEAREST` for pixel art
4. Adjust collision shapes to match tile dimensions
5. Test collision placement at top surface (Y=-54 offset)

The "borders" you're seeing are just the art style - they create the 3D beveled appearance!
