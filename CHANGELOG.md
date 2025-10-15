# Changelog

All notable changes to Bounce Ascent will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-10-14

### 🎮 Gameplay Overhaul - Mario-Style Jump System

#### Changed
- **Complete Jump Mechanic Redesign**
  - Removed rhythm-based auto-bounce system entirely
  - Implemented Mario-style super jump timing mechanic
  - Normal jumps: -500 velocity (any time)
  - Super jumps: -900 velocity (within 150ms landing window)
  - Combo chain system: Each successful super jump adds -100 velocity bonus
  - Landing window: 0.15 seconds after touching platform

- **Button Input Anti-Exploit**
  - Manual edge detection prevents button holding exploit
  - Players must release and re-press jump button for timing to count
  - Jump state tracked across frames to detect actual button presses
  - Fixed: Holding spacebar no longer counts as perfectly timed jumps

- **Camera System Overhaul**
  - Changed from fixed auto-scroll to player-following camera
  - Camera follows player with smooth lerp (follow_smoothness = 5.0)
  - Uses `min(target_y, player.y)` to never slow down while following
  - Maintains upward pressure while staying centered on player

- **Aggressive Difficulty Scaling**
  - Initial scroll speed: 50 px/s (was 25 px/s) - **2× faster start**
  - Max scroll speed: 400 px/s (was 250 px/s) - **60% increase**
  - Speed increase rate: 2.0 px/s² (was 0.4 px/s²) - **5× faster acceleration**
  - Space zone starts at height 300 (was 600) - **earlier difficulty spike**
  - Space zone duration: 200 height (was 400) - **tighter ramp**
  - Space multiplier: 2.5× (was 2.0×) - **25% faster in space**
  - Maximum effective speed: 1000 px/s (400 × 2.5)

- **Visual Scaling Adjustments**
  - Platforms scaled to 50% size (128px tiles → 64px rendered)
  - Ball increased 50% in size: 96px → 144px diameter
  - Player collision radius updated: 48px → 72px
  - Tighter, more challenging platform spacing

#### Added
- **Ball Squash-and-Stretch Animation**
  - 4-state animation system: idle, charge_jump, jump, landing
  - 128×128 sprite frames from custom ball sprite sheet
  - Visual feedback tied to player actions
  - Animations trigger on landing, jumping, and idle states

- **Countdown Removal**
  - Removed 3-second countdown system
  - Game starts immediately when entering play scene
  - Physics enabled right away for faster gameplay loop

#### Removed
- All rhythm-based bounce variables (bounce_timer, current_bounce_interval)
- Timing window system (PERFECT/CLOSE markers)
- Auto-bounce functionality
- Countdown circle and "CLIMB!" message
- Rhythm feedback UI elements

#### Fixed
- GameUI.gd accessing removed rhythm variables
- Button holding exploit allowing free super jumps
- Parser error from non-existent `is_physical_key_just_pressed()` function
- Collision radius mismatch with new ball size

#### Technical Changes
- **Player.gd**: Complete rewrite for Mario jump system
  - Added `can_super_jump`, `time_since_landing`, `jump_was_pressed` variables
  - Implemented manual button edge detection logic
  - Progressive combo velocity calculation
  - Ball animation state machine integration

- **GameCamera.gd**: Player-following with aggressive difficulty
  - Dual tracking: scroll target vs player position
  - Exponential difficulty curve in space zone
  - Smooth camera interpolation

- **TileMapPlatform.gd**: 50% scale applied to all platforms
- **Player.tscn**: Updated collision shape and ball sprite animations
- **Game.gd**: Removed countdown initialization logic
- **GameUI.gd**: Updated for super jump feedback system

### Performance
- Removed unused countdown label nodes
- Simplified input detection (manual edge detection faster than multiple Input checks)
- Removed rhythm timing calculations every frame

## [0.1.1] - 2025-10-13

### Added
- **Tile-Based Platform System**
  - Modular platform generation using left, middle, and right tile pieces
  - Platforms now have 0-2 random middle pieces for varied widths (256px-512px)
  - Ground row uses seamless middle tiles across the bottom
  - 314 auto-generated atlas textures from Kenney spritesheet
  - Tool scripts for tile generation (`generate_tileset.gd`, `generate_atlas_textures.gd`)

- **Documentation**
  - `docs/TILESET_GUIDE.md` - Guide for understanding and using Kenney tiles
  - `CHANGELOG.md` - Version history tracking

### Changed
- **Scale Adjustments for 128×128 Tiles**
  - Camera zoom adjusted to 0.6× for proper visibility
  - Platform vertical spacing increased from 100px to 180px
  - Player collision radius set to 32px (was variable)
  - Background expanded from 800×1000px to 1400×1800px
  - Camera scroll speed reduced from 30 px/s to 25 px/s
  - UI text sizes adjusted for better readability
  - Countdown circle and HUD elements repositioned

- **Visual Improvements**
  - All tiles use nearest neighbor filtering for pixel-perfect rendering
  - Platforms now have natural grass tile appearance with rounded edges
  - Ground seamlessly connects across screen width

### Fixed
- **Collision System Overhaul**
  - Precision collision boxes (20px thin) positioned at top surface only (Y=-54)
  - Prevents ball from getting stuck inside platforms
  - Removed redundant starting platform that caused immediate game over
  - Ground collision now matches platform collision for consistency
  - Fixed collision offset calculations for 128px tile height

- **Game Start Issues**
  - Fixed immediate game over bug after countdown
  - Player now starts at better position (y=400 instead of y=800)
  - Countdown properly initializes game state before play

### Technical
- Platform collision shapes sized to match actual tile dimensions
- Dynamic sprite creation for modular platform assembly
- Collision positioned at visual top of grass surface
- AtlasTexture regions extracted from 128×128 tile grid
- Spritesheet tiles at positions (7,9), (7,10), (7,11) for platforms

## [0.1.0] - 2025-10-09

### Initial Release Features

#### Core Gameplay
- Rhythm-based auto-bounce every 1.5 seconds
- Manual jump timing system with PERFECT/CLOSE windows
- Combo system with progressive difficulty
- Horizontal movement with arrow keys or WASD
- Scrolling camera with death zone

#### Platform System (Pre-Tiles)
- Four platform types: Static, Moving, Breakable, Temporary
- Procedural generation with 5 difficulty tiers
- Dynamic spawning based on camera position
- Platform cleanup when off-screen

#### Visual Features
- Dynamic background color transitions (sky → sunset → dusk → space)
- Particle effects for breaking platforms
- Animated feedback for jumps (scale + wiggle)
- Timing ring with color-coded windows
- Combo counter display in ball center

#### Profile System
- Encrypted save files with AES-256
- Username and ball color customization
- 8 preset ball colors
- Profile editor UI
- Comprehensive statistics tracking

#### Statistics Tracked
- High score calculation
- Total runs and deaths
- Height reached and platforms landed
- Time survived
- Platforms broken
- Edge escape attempts
- Rage quits detection

#### Anti-Cheat Security
- AES-256 encryption of profile data
- SHA-256 hash validation
- HMAC cryptographic signatures
- Runtime physics validation
- Impossibility detection

#### UI/UX
- Main menu with profile display
- In-game HUD showing height, bounce timer, platforms
- Game over screen with session statistics
- Profile editor with color picker
- ESC key support for menu navigation
- 3-second countdown before gameplay

#### Export Configurations
- Windows executable (.exe)
- Linux executable (x86_64)
- macOS application bundle (.app)
- Windows Defender warning documentation

#### Technical Architecture
- GameManager singleton for global state
- Save/load system with encryption
- Modular platform class hierarchy
- Camera-based procedural spawning
- Physics-based character controller

---

## Version Number Scheme

- **Major (X.0.0)**: Complete gameplay overhauls, incompatible changes
- **Minor (0.X.0)**: New features, significant updates
- **Patch (0.0.X)**: Bug fixes, minor tweaks

[0.2.0]: https://github.com/Synthetic-Virus/Bounce-Ascent/releases/tag/v0.2.0
[0.1.1]: https://github.com/Synthetic-Virus/Bounce-Ascent/releases/tag/v0.1.1
[0.1.0]: https://github.com/Synthetic-Virus/Bounce-Ascent/releases/tag/v0.1.0
