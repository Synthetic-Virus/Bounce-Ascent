# Bounce Ascent 🎮

[![Godot Engine](https://img.shields.io/badge/Godot-4.3+-blue.svg)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)]()

A challenging 2D endless platformer where you control a bouncing ball that must ascend endlessly higher while avoiding falling behind the scrolling screen.

![Game Screenshot](https://via.placeholder.com/800x400/1a1a2e/4b9eff?text=Bounce+Ascent+Gameplay)
*Screenshot placeholder - replace with actual gameplay*

## Game Features

### Core Gameplay
- **Rhythm-Based Bouncing**: Ball automatically bounces every 1.5 seconds
- **Timing System**: Press spacebar during timing windows for bonus height:
  - **PERFECT!** (Green/0.1s window): Maximum height boost
  - **CLOSE!** (Yellow/0.2s window): Good height boost
- **Combo System**: Successive successful timings increase:
  - Bounce speed (faster rhythm, down to 0.5s minimum)
  - Jump height (-50 velocity per combo level)
  - Visual feedback (combo counter in ball center)
- **Horizontal Movement**: Control left/right with arrow keys or WASD
- **Scrolling Camera**: Screen scrolls upward - don't fall behind!
- **Progressive Difficulty**: Game speeds up dramatically in space zone (600+ height)

### Platform Types

1. **Static Platforms** (Green) - Basic solid platforms
2. **Moving Platforms** (Yellow) - Oscillate horizontally
3. **Breakable Platforms** (Red) - Dissolve over 0.5s, player falls through at 80% dissolved
4. **Temporary Platforms** (Purple) - Flash warning then fall after 2 seconds

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
- Base scroll speed: 30 px/s
- Max scroll speed: 300 px/s (was 120)
- Space zone (600-1000 height): Progressive speed multiplier up to 2x

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
- **Spacebar** or **Up Arrow** or **W**: Time your bounce (press during green/yellow timing windows)
- **ESC**: Return to menu / Quit game

### Timing Guide
- **Visual Ring**: White ring fills around ball showing bounce timer
- **Green Marker**: PERFECT timing window (0.2s before auto-bounce)
- **Yellow Marker**: CLOSE timing window (0.1s before auto-bounce)
- **Combo Counter**: Number inside ball shows current combo streak
- **Feedback Text**: "PERFECT!" or "CLOSE!" displays after successful timing

## Technical Features

### Visual Style
- **Geometric Shapes**: Circles (ball) and rounded rectangles (platforms)
- **Black Outlines**: 3px outlines on all game elements for visibility
- **Text Outlines**: All UI text has black outlines for readability on any background
- **Neon Color Palette**: Bright colors with customizable ball colors
- **Dynamic Background**: Smooth color transitions from sky → sunset → dusk → space
- **Particle Effects**: Break particles when platforms shatter
- **Animated Feedback**:
  - CLOSE jumps: 1.2x scale + wiggle animation
  - PERFECT jumps: 1.5x scale + dramatic wiggle animation
  - Timing ring with color-coded windows
  - Combo burst effects

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
- **Engine**: Godot 4.3
- **Language**: GDScript
- **Graphics**: Custom shaders (GLSL)

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
- **Player**: Physics-based character controller with jump mechanics
- **PlatformSpawner**: Procedural platform generation with difficulty scaling
- **GameCamera**: Scrolling camera with death zone detection
- **Platform Types**: Base class with specialized variants (moving, breakable, temporary)

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
- [`GETTING_STARTED.md`](GETTING_STARTED.md) - Setup and quick start
- [`QUICKSTART.md`](QUICKSTART.md) - Developer reference
- [`EXPORT_INSTRUCTIONS.md`](EXPORT_INSTRUCTIONS.md) - How to export builds
- [`PROJECT_SUMMARY.md`](PROJECT_SUMMARY.md) - Complete feature list
- [`CONTRIBUTING.md`](CONTRIBUTING.md) - Contribution guidelines

---

**Enjoy the game!** 🎮 If you encounter issues, please [open an issue](../../issues).
