# Bounce Ascent - Sprite Conversion Plan

## Current Architecture (Procedural Drawing)

**Current System:**
- All visuals use GDScript `_draw()` functions
- Geometry drawn at runtime (circles, rectangles, lines)
- Textures created with code (wood grain, rubber patterns)
- No external image files

**Files Using _draw():**
1. `Player.gd` - Ball with rubber texture
2. `Platform.gd` - Rounded platforms with wood grain
3. `DynamicBackground.gd` - Stars drawn as circles

## Why Convert to Sprites?

**Advantages:**
- Better visual quality and artistic control
- Easier to create complex textures and effects
- Better performance (GPU-optimized texture rendering)
- Easier to iterate on visual design
- Can use pixel art or hand-drawn assets

**Disadvantages:**
- Need to create/source sprite assets
- Larger file size (images vs code)
- Less programmatic flexibility

## Sprite-Based Architecture Plan

### 1. Asset Requirements

**Ball Sprite:**
- Size: 32x32 pixels (16px radius × 2)
- Format: PNG with transparency
- Variants: 8 colors (matching current color options)
- Style: Rubber texture, shine highlight
- Files needed:
  - `ball_blue.png` (default neon blue)
  - `ball_red.png`
  - `ball_green.png`
  - `ball_yellow.png`
  - `ball_purple.png`
  - `ball_orange.png`
  - `ball_cyan.png`
  - `ball_pink.png`

**Platform Sprites:**
- Size: Variable width × 20px height
- Format: PNG with transparency
- Types: 4 platform types
- Style: Wood grain texture, rounded corners (8px)
- Approach: Use 9-slice scaling (NinePatchRect)
- Files needed:
  - `platform_static.png` (green, 60×20px minimum)
  - `platform_moving.png` (yellow)
  - `platform_breakable.png` (red)
  - `platform_temporary.png` (purple)

**Background:**
- Option 1: Keep procedural (stars are simple)
- Option 2: Create gradient sprites for sky layers
- Recommendation: Keep procedural for dynamic transitions

### 2. Code Changes Required

#### A. Player.gd Conversion

**Current:**
```gdscript
func _ready():
    # Creates CollisionShape2D
    # Calls queue_redraw()

func _draw():
    # Draws circle, lines, highlights
```

**New Sprite-Based:**
```gdscript
var sprite: Sprite2D

func _ready():
    # Create collision shape (same)
    var collision = CollisionShape2D.new()
    var circle = CircleShape2D.new()
    circle.radius = player_radius
    collision.shape = circle
    add_child(collision)

    # Create sprite
    sprite = Sprite2D.new()
    sprite.texture = load_ball_texture()
    sprite.centered = true
    add_child(sprite)

func load_ball_texture() -> Texture2D:
    var color = GameManager.get_ball_color()
    # Map color to sprite file
    if color.is_equal_approx(Color(0.29, 0.62, 1.0)):
        return load("res://assets/sprites/ball_blue.png")
    elif color.is_equal_approx(Color(1.0, 0.3, 0.3)):
        return load("res://assets/sprites/ball_red.png")
    # ... etc for all 8 colors
    return load("res://assets/sprites/ball_blue.png")

# Remove _draw() function entirely
```

#### B. Platform.gd Conversion

**Current:**
```gdscript
func _draw():
    # Draws rounded rectangles
    # Draws wood grain lines
```

**New Sprite-Based (Option 1: NinePatchRect):**
```gdscript
var nine_patch: NinePatchRect

func _ready():
    add_to_group("platform")

    # Set up collision (same)
    var collision = CollisionShape2D.new()
    var rect = RectangleShape2D.new()
    rect.size = Vector2(platform_width, platform_height)
    collision.shape = rect
    add_child(collision)

    # Create NinePatchRect for scalable platform
    nine_patch = NinePatchRect.new()
    nine_patch.texture = get_platform_texture()
    nine_patch.region_rect = Rect2(0, 0, 60, 20)
    nine_patch.patch_margin_left = 8
    nine_patch.patch_margin_right = 8
    nine_patch.patch_margin_top = 4
    nine_patch.patch_margin_bottom = 4
    nine_patch.size = Vector2(platform_width, platform_height)
    nine_patch.position = Vector2(-platform_width/2, -platform_height/2)
    add_child(nine_patch)

func get_platform_texture() -> Texture2D:
    match platform_type:
        PlatformType.STATIC:
            return load("res://assets/sprites/platform_static.png")
        PlatformType.MOVING:
            return load("res://assets/sprites/platform_moving.png")
        PlatformType.BREAKABLE:
            return load("res://assets/sprites/platform_breakable.png")
        PlatformType.TEMPORARY:
            return load("res://assets/sprites/platform_temporary.png")
    return load("res://assets/sprites/platform_static.png")

# Remove _draw() function entirely
```

**New Sprite-Based (Option 2: Tiled Sprite):**
```gdscript
var sprite: Sprite2D

func _ready():
    # ... collision setup same

    # Create sprite with repeat region
    sprite = Sprite2D.new()
    sprite.texture = get_platform_texture()
    sprite.region_enabled = true
    sprite.region_rect = Rect2(0, 0, platform_width, platform_height)
    sprite.centered = true
    add_child(sprite)
```

#### C. Background - Keep Mostly Procedural

**Recommendation:** Keep current system with minor changes
- Color transitions work well procedurally
- Stars are simple circles - could convert to sprites if desired

**Optional Star Sprite:**
```gdscript
# In DynamicBackground.gd
func setup_background(camera: Camera2D):
    camera_ref = camera
    var star_texture = load("res://assets/sprites/star.png")

    for i in range(MAX_STARS):
        var star_sprite = Sprite2D.new()
        star_sprite.texture = star_texture
        star_sprite.position = Vector2(randf() * 800, randf() * 1000)
        star_sprite.modulate.a = randf()  # Random brightness
        star_sprite.scale = Vector2.ONE * randf_range(0.5, 1.5)
        add_child(star_sprite)
        stars.append(star_sprite)

# Remove _draw() for stars
```

### 3. Directory Structure

```
bounce-ascent/
├── assets/
│   └── sprites/
│       ├── ball_blue.png
│       ├── ball_red.png
│       ├── ball_green.png
│       ├── ball_yellow.png
│       ├── ball_purple.png
│       ├── ball_orange.png
│       ├── ball_cyan.png
│       ├── ball_pink.png
│       ├── platform_static.png
│       ├── platform_moving.png
│       ├── platform_breakable.png
│       ├── platform_temporary.png
│       └── star.png (optional)
├── scenes/
├── scripts/
└── resources/
```

### 4. Implementation Steps

**Phase 1: Create Assets**
1. Design ball sprites (8 colors) - 32×32px
2. Design platform sprites (4 types) - 60×20px with 9-slice support
3. Optional: Create star sprite - 8×8px

**Phase 2: Convert Player**
1. Backup current Player.gd
2. Replace _draw() with Sprite2D
3. Implement color-to-sprite mapping
4. Test ball physics and collision
5. Verify all 8 colors work

**Phase 3: Convert Platforms**
1. Backup current Platform.gd
2. Choose NinePatchRect or Tiled approach
3. Replace _draw() with sprite system
4. Test all 4 platform types
5. Verify collision and sizing

**Phase 4: Background (Optional)**
1. Convert stars to sprites if desired
2. Keep color gradient procedural

**Phase 5: Testing**
1. Test all gameplay features
2. Verify performance
3. Check visual quality
4. Export and test .exe

### 5. Asset Creation Tools

**Option 1: Create Your Own**
- Aseprite (pixel art editor) - $19.99
- GIMP (free)
- Photoshop
- Krita (free)

**Option 2: Use AI Generation**
- DALL-E, Midjourney, Stable Diffusion
- Prompt: "32x32 pixel art rubber ball with shine, transparent background"

**Option 3: Use Godot's Built-in Tools**
- Can still use _draw() to generate images, then save to files
- Create sprites programmatically once, export as PNG

### 6. Hybrid Approach (Recommended for Now)

**Keep what works:**
- Background gradients (procedural)
- Stars (simple circles)

**Convert for quality:**
- Ball (better rubber texture with real art)
- Platforms (better wood grain, more artistic)

**Why Hybrid?**
- Focus art effort on main gameplay elements
- Keep flexibility where it's useful
- Easier transition (convert piece by piece)

### 7. Performance Considerations

**Current (Procedural):**
- CPU: Low (simple geometry)
- GPU: Medium (many draw calls)
- Memory: Very low (no textures)

**Sprite-Based:**
- CPU: Very low (just positioning)
- GPU: Low (batched sprite rendering)
- Memory: Medium (texture atlas ~1-2MB)

**Verdict:** Sprites will likely perform better with many platforms

### 8. Alternative: Texture Atlas

**For best performance:**
```
Create single texture atlas containing:
- All 8 ball variants
- All 4 platform types (at base size)
- Stars, particles, etc.

Use AtlasTexture in Godot:
- Loads once
- All sprites share one texture
- GPU batching maximizes performance
```

### 9. Quick Start: Generate Sprites from Current Code

**Step 1: Capture Current Visuals**
```gdscript
# Add to Player.gd temporarily
func save_ball_sprite():
    var viewport = SubViewport.new()
    viewport.size = Vector2i(32, 32)
    viewport.transparent_bg = true

    var temp_player = CharacterBody2D.new()
    temp_player.set_script(load("res://scripts/Player.gd"))
    viewport.add_child(temp_player)

    await RenderingServer.frame_post_draw
    var img = viewport.get_texture().get_image()
    img.save_png("res://assets/sprites/ball_blue.png")
```

**Step 2: Repeat for All Colors**
- Loop through 8 colors
- Generate 8 sprite files
- Same for platforms

**Step 3: Switch to Sprite System**
- Load generated PNGs instead of drawing

This gives you sprites that look identical to current game!

## Summary

**Easiest Path:**
1. Keep current procedural system (it works!)
2. Only convert if you want custom artwork

**Best Quality Path:**
1. Create/commission professional sprites
2. Convert to full sprite-based system
3. Use texture atlas for performance

**Recommended Path:**
1. Generate sprites from current _draw() code
2. Convert to sprite system (identical visuals)
3. Later: Replace with better artwork if desired

Would you like me to implement any of these approaches?
