# TileSet Usage Guide

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

## For Bounce Ascent Integration

Since Bounce Ascent uses procedural platforms, you could:
- Use `block_*` tiles for hand-designed level sections
- Use terrain tiles for background decoration
- Mix tilemap platforms with your existing procedural spawning

The "borders" you're seeing are just the art style - try using `block_blue` or `terrain_grass_cloud` for clean, simple platforms!
