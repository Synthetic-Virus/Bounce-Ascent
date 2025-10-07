# Bounce Ascent 🎮

[![Godot Engine](https://img.shields.io/badge/Godot-4.3+-blue.svg)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)]()

A challenging 2D endless platformer where you control a bouncing ball that must ascend endlessly higher while avoiding falling behind the scrolling screen.

![Game Screenshot](https://via.placeholder.com/800x400/1a1a2e/4b9eff?text=Bounce+Ascent+Gameplay)
*Screenshot placeholder - replace with actual gameplay*

## Game Features

### Core Gameplay
- **Auto-Jump Mechanic**: Ball automatically jumps every 2.5 seconds
- **Manual Jump**: Force a jump anytime with spacebar/up arrow (with cooldown)
- **Horizontal Movement**: Control left/right movement with arrow keys or WASD
- **Scrolling Camera**: Screen scrolls downward - don't fall behind!
- **Progressive Difficulty**: Game gets harder as you climb higher

### Platform Types

1. **Static Platforms** (Green) - Basic solid platforms
2. **Moving Platforms** (Yellow) - Oscillate horizontally
3. **Breakable Platforms** (Red) - Shatter after landing once
4. **Temporary Platforms** (Purple) - Disappear after a short time

### Difficulty Tiers

- **Tier 1 (0-50 height)**: Static platforms only
- **Tier 2 (50-100)**: Moving platforms introduced
- **Tier 3 (100-150)**: Breakable platforms added
- **Tier 4 (150-200)**: Temporary platforms appear
- **Tier 5 (200+)**: Smaller platforms, larger gaps, faster scroll speed

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
- **Spacebar** or **Up Arrow** or **W**: Force a jump
- **ESC**: Quit game

## Technical Features

### Visual Style
- Simple geometric shapes (circles and rectangles)
- Neon color palette
- CRT monitor effect with:
  - Scanlines
  - Chromatic aberration
  - Vignette
  - Screen noise

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
- Username and high score
- Cumulative statistics across all runs
- Session history

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
