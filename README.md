# Bounce Ascent 🎮

[![Godot Engine](https://img.shields.io/badge/Godot-4.3+-blue.svg)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)]()

A challenging 2D endless platformer where you control a bouncing ball that must ascend endlessly higher while avoiding falling behind the scrolling screen.

![Game Screenshot](https://via.placeholder.com/800x400/1a1a2e/4b9eff?text=Bounce+Ascent+Gameplay)
*Screenshot placeholder - replace with actual gameplay*

## Game Features

### Core Gameplay
- **Mario-Style Super Jump**: Time your jumps perfectly with landing for maximum height
  - **Normal Jump**: -500 velocity (press jump anytime)
  - **Super Jump**: -900 velocity (press jump within 150ms of landing)
  - **Landing Window**: 0.15 second timing window after each landing
  - **No Button Holding**: Must release and re-press jump button for timing to count
- **Combo Chain System**: Successive super jumps increase height progressively
  - Each successful super jump adds -100 velocity bonus
  - Combo counter displays inside ball
  - Missing a super jump resets combo to 0
- **Squash-and-Stretch Animation**: Ball animates with:
  - Idle, charge, jump, and landing animations
  - Visual feedback for player actions
- **Horizontal Movement**: Control left/right with arrow keys or WASD
- **Following Camera**: Camera follows player while auto-scrolling upward
- **Aggressive Difficulty**: Game speeds up much faster (2x start speed, 5x acceleration rate)

### Platform Types

Platforms are built using modular tile pieces from the Kenney platformer pack (128×128 tiles, scaled to 50%):

1. **Static Platforms** (Green grass tiles) - Basic solid platforms with 0-2 random middle pieces
2. **Moving Platforms** (Yellow) - Oscillate horizontally
3. **Breakable Platforms** (Red) - Dissolve over 0.5s, player falls through at 80% dissolved
4. **Temporary Platforms** (Purple) - Flash warning then fall after 2 seconds

Each platform consists of:
- **Left edge tile** (rounded left side)
- **0-2 middle tiles** (for varied platform widths)
- **Right edge tile** (rounded right side)
- **Scale**: All platforms rendered at 50% size for tighter gameplay

### Difficulty Progression

**Platform Tiers:**
- **Tier 1 (0-50 height)**: Static platforms only
- **Tier 2 (50-100)**: Moving platforms introduced (30% chance)
- **Tier 3 (100-150)**: Breakable platforms added (20% chance)
- **Tier 4 (150-200)**: Temporary platforms appear (15% chance)
- **Tier 5 (200+)**: Smaller platforms, larger gaps

**Visual Transitions:**
- **Sky (0-200)**: Light blue starting zone
- **Sunset (200-400)**: Orange/pink transition
- **Dusk (400-600)**: Purple twilight with emerging stars
- **Space (600+)**: Deep space with stars, 2x speed multiplier kicks in

**Speed Scaling:**
- Initial scroll speed: 50 px/s (2× faster than before)
- Max scroll speed: 400 px/s
- Speed increase rate: 2.0 px/s² (5× faster acceleration)
- Space zone (300+ height): Progressive speed multiplier up to 2.5×
- Maximum effective speed: 1000 px/s (in deep space)

### Scoring System

Your score is calculated from:
- **Height Reached** × 10 points
- **Platforms Landed** × 5 points
- **Time Survived** × 2 points

### Statistics Tracked

- High Score
- Total Runs
- Total Height Reached
- Total Platforms Landed
- Platforms Broken
- Time Survived
- Edge Escape Attempts (trying to go off screen)
- Deaths
- Rage Quits (closing game during active session)

## Controls

- **Left/Right Arrow** or **A/D**: Move horizontally
- **Spacebar** or **Up Arrow** or **W**: Jump (press within 150ms of landing for super jump)
- **ESC**: Return to menu / Quit game / Close profile editor

### Jump Timing Guide
- **Landing Animation**: Watch for the landing animation to play
- **Timing Window**: 150ms window after landing to press jump for super jump
- **Button Release Required**: Must release jump button between presses (no holding!)
- **Combo Counter**: Number inside ball shows current super jump combo streak
- **Feedback Text**: "SUPER JUMP!" displays after successful timing
- **Visual Feedback**: Ball plays squash-and-stretch animations during jumps

## Technical Features

### Visual Style
- **Tile-Based Graphics**: Using 128×128 Kenney platformer pack tiles (scaled to 50%)
- **Large Ball Sprite**: 144px diameter ball (50% larger than before)
- **Modular Platforms**: Dynamic assembly of left, middle, and right tile pieces
- **Squash-and-Stretch**: Professional ball animation with 4 states (idle, charge, jump, landing)
- **Pixel Perfect**: Nearest neighbor filtering for crisp retro aesthetics
- **Camera Zoom**: 0.6× zoom to accommodate larger tile sizes
- **Black Outlines**: Clean borders on all game elements
- **Text Outlines**: All UI text has black outlines for readability on any background
- **Neon Color Palette**: Bright colors with customizable ball colors (8 presets)
- **Dynamic Background**: Smooth color transitions from sky → sunset → dusk → space (1400×1800px)
- **Particle Effects**: Break particles when platforms shatter
- **Animated Feedback**:
  - Super jumps: Visual burst and combo counter display
  - Ball animations react to player actions
  - Landing animation triggers timing window

### Anti-Cheat Security

The game implements multiple layers of save file protection:

1. **Encryption**: AES-256 encryption of all profile data
2. **Checksums**: SHA-256 hash validation
3. **HMAC Signatures**: Cryptographic signing with embedded secret key
4. **Runtime Validation**: Physics and statistics validation
5. **Impossibility Detection**: Validates that stats correlate properly

Save files cannot be easily edited to cheat high scores!

### Profile System

All player data is stored in an encrypted profile file including:
- **Customization**: Username and ball color (8 preset colors)
- **High Score**: Best score achieved across all runs
- **Cumulative Statistics**: Total runs, height, platforms, time survived
- **Session History**: Detailed per-run statistics
- **Profile Editor**: In-game UI for customization and viewing stats

## Development

### Built With
- **Engine**: Godot 4.3+ (Godot 4.5 compatible)
- **Language**: GDScript
- **Graphics**: Kenney platformer pack (128×128 tiles)
- **Shaders**: Custom GLSL shaders (CRT effects)

### Project Structure

```
bounce-ascent/
├── scenes/          # Scene files (.tscn)
├── scripts/         # GDScript files
├── resources/       # Shaders, fonts, etc.
└── assets/          # Particles and effects
```

### Key Systems

- **GameManager** (Singleton): Handles profiles, save/load, statistics, anti-cheat
- **Player**: Physics-based character controller with Mario-style super jump mechanics
  - Manual edge detection for button input (prevents holding exploit)
  - Combo chain system with progressive height scaling
  - Ball animation state machine
- **PlatformSpawner**: Procedural platform generation with difficulty scaling
- **GameCamera**: Player-following camera with aggressive auto-scroll
  - Smooth lerp following (follow_smoothness = 5.0)
  - Progressive speed increase (2.0 px/s²)
  - Space zone speed multiplier (up to 2.5×)
- **Platform Types**: TileMapLayer-based platforms with physics
  - Base class with specialized variants (moving, breakable, temporary)
  - 50% scale for tighter gameplay

## 🚀 Getting Started

### Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/Bounce-Ascent.git
   cd Bounce-Ascent
   ```

2. **Install Godot 4.3+**: Download from [godotengine.org](https://godotengine.org/download)

3. **Open the project**:
   ```bash
   godot project.godot
   ```

4. **Play**: Press `F5` in the Godot Editor

See [`GETTING_STARTED.md`](GETTING_STARTED.md) for detailed setup instructions.

## 📦 Exporting

See [`EXPORT_INSTRUCTIONS.md`](EXPORT_INSTRUCTIONS.md) for detailed instructions on creating executables for:
- Windows (.exe)
- Linux (x86_64)
- macOS (.app)

## 🤝 Contributing

Contributions are welcome! Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) for guidelines.

### Areas We Need Help With:
- 🎵 Audio/Music implementation
- 🎨 Additional visual effects
- 🎮 New platform types
- ⚖️ Balance testing
- 🌍 Translations

## 📝 License

This project is licensed under the MIT License - see the [`LICENSE`](LICENSE) file for details.

## 🙏 Credits

- **Engine**: [Godot Engine](https://godotengine.org)
- **Development**: Created with Claude Code
- **Contributors**: See [contributors](../../graphs/contributors)

## 📚 Documentation

- [`README.md`](README.md) - This file
- [`CHANGELOG.md`](CHANGELOG.md) - Version history and release notes
- [`GETTING_STARTED.md`](GETTING_STARTED.md) - Setup and quick start
- [`QUICKSTART.md`](QUICKSTART.md) - Developer reference
- [`EXPORT_INSTRUCTIONS.md`](EXPORT_INSTRUCTIONS.md) - How to export builds
- [`PROJECT_SUMMARY.md`](PROJECT_SUMMARY.md) - Complete feature list
- [`CONTRIBUTING.md`](CONTRIBUTING.md) - Contribution guidelines
- [`docs/TILESET_GUIDE.md`](docs/TILESET_GUIDE.md) - Tile system implementation guide

---

**Enjoy the game!** 🎮 If you encounter issues, please [open an issue](../../issues).
