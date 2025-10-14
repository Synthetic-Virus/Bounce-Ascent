# Getting Started with Bounce Ascent

## 🎮 Project Complete!

Your Bounce Ascent game is ready to play and develop. Here's everything you need to know to get started.

## ✅ What's Been Built

A complete 2D endless platformer with:
- ✅ Player physics and controls
- ✅ 4 types of platforms (static, moving, breakable, temporary)
- ✅ Progressive difficulty scaling
- ✅ Encrypted save system with anti-cheat
- ✅ Full UI (menu, HUD, game over)
- ✅ CRT visual effects
- ✅ Statistics tracking
- ✅ Export configurations for Windows/Linux/Mac

## 🚀 Quick Start

### 1. Verify Installation

Run the verification script:
```bash
cd /home/virus/bounce-ascent
./verify_project.sh
```

This checks that all files are present and Godot is installed.

### 2. Open in Godot Editor

```bash
cd /home/virus/bounce-ascent
/snap/bin/godot-4 project.godot
```

This opens the Godot Editor where you can:
- View/edit scenes
- Modify scripts
- Test the game (press F5)
- Configure export settings

### 3. Play the Game

Once in the editor, press **F5** to run the game!

Or run directly:
```bash
cd /home/virus/bounce-ascent
/snap/bin/godot-4 --path . res://scenes/MainMenu.tscn
```

## 🎯 Game Controls

- **Arrow Keys** or **WASD**: Move left/right
- **Spacebar** or **Up Arrow**: Force a jump (with cooldown)
- **ESC**: Quit to desktop

The ball auto-jumps every 2.5 seconds - you can supplement with manual jumps!

## 📂 Project Files

```
bounce-ascent/
├── 📄 Documentation
│   ├── README.md                    # Full project overview
│   ├── QUICKSTART.md                # Development quick reference
│   ├── EXPORT_INSTRUCTIONS.md       # How to export executables
│   ├── PROJECT_SUMMARY.md           # Detailed feature list
│   └── GETTING_STARTED.md           # This file!
│
├── 🎮 Game Files
│   ├── project.godot                # Godot project config
│   ├── export_presets.cfg           # Export settings
│   │
│   ├── scenes/                      # Scene files
│   │   ├── MainMenu.tscn
│   │   ├── Game.tscn
│   │   └── GameOver.tscn
│   │
│   ├── scripts/                     # Game logic (GDScript)
│   │   ├── GameManager.gd           # Saves, stats, anti-cheat
│   │   ├── Player.gd                # Player controller
│   │   ├── Platform.gd              # Base platform
│   │   ├── MovingPlatform.gd
│   │   ├── BreakablePlatform.gd
│   │   ├── TemporaryPlatform.gd
│   │   ├── PlatformSpawner.gd       # Procedural generation
│   │   ├── GameCamera.gd            # Scrolling camera
│   │   ├── GameUI.gd                # In-game UI
│   │   ├── Game.gd                  # Main game loop
│   │   ├── MainMenu.gd
│   │   └── GameOver.gd
│   │
│   └── resources/
│       └── shaders/
│           └── crt_shader.gdshader  # CRT visual effect
│
└── 🛠️ Utilities
    └── verify_project.sh            # Verification script
```

## 🎨 Customization Quick Guide

### Change Player Name
Edit `scripts/GameManager.gd`, line ~52:
```gdscript
"username": "Player",  # Change this!
```
Then delete the save file to recreate profile.

### Adjust Difficulty
Edit `scripts/PlatformSpawner.gd`:
- Lines 16-20: Change when new platform types appear
- Line 11: Adjust platform spacing

### Change Jump Height
Edit `scripts/Player.gd`:
- Line 6: `JUMP_VELOCITY` (more negative = higher jump)
- Line 5: `MOVE_SPEED` (horizontal speed)

### Disable CRT Shader
Edit `scripts/Game.gd`, line 21:
```gdscript
# add_crt_shader()  # Comment this out
```

## 🏗️ Next Steps

### For Playing/Testing
1. Run verification script ✅
2. Open in Godot Editor
3. Press F5 to play
4. Test all mechanics
5. Try to beat your high score!

### For Development
1. **Balance tuning**: Play multiple rounds and adjust difficulty
2. **Add audio**: Create sound effects for jumps, landings, breaks
3. **Visual polish**: Add particle effects, screen shake, trails
4. **Export builds**: Follow `EXPORT_INSTRUCTIONS.md` to create .exe

### For Distribution
1. Test thoroughly
2. Follow export instructions
3. Enable encryption (anti-cheat)
4. Create builds for Windows/Linux/Mac
5. Share your game!

## 🔧 Troubleshooting

### Godot won't open
- Ensure Godot 4.x is installed: `/snap/bin/godot-4 --version`
- Try running with full path: `/snap/bin/godot-4 project.godot`

### Game crashes on start
- Check Godot console for errors
- Ensure all scripts are in `scripts/` folder
- Verify GameManager is set as autoload in project settings

### Save file not working
- Check permissions on `~/.local/share/godot/app_userdata/`
- Look for error messages in Godot output
- Delete corrupted save to start fresh

### Performance issues
- Disable CRT shader (see customization above)
- Reduce platform spawn rate in PlatformSpawner.gd
- Check Godot profiler (Debug → Profiler)

## 📊 Current Status

**✅ COMPLETE - Core Implementation**
- All gameplay mechanics working
- Save system with encryption
- Anti-cheat validation
- Full UI flow
- Export ready

**⏳ PENDING - Optional Enhancements**
- Audio/music (requires sound assets)
- Playtesting/balance refinement
- Additional visual effects
- Achievement system

## 📝 File Locations

### Game Save Files
**Linux**: `~/.local/share/godot/app_userdata/Bounce Ascent/profile.save`
**Windows**: `%APPDATA%/Godot/app_userdata/Bounce Ascent/profile.save`
**macOS**: `~/Library/Application Support/Godot/app_userdata/Bounce Ascent/profile.save`

### Exported Builds
When you export, files go to: `./exports/` (created automatically)

## 🎓 Learning Resources

- **Godot Docs**: https://docs.godotengine.org/en/stable/
- **GDScript Reference**: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/
- **Exporting Projects**: https://docs.godotengine.org/en/stable/tutorials/export/

## ✨ You're Ready!

Run the verification script, open Godot, and press F5 to play your game!

```bash
cd /home/virus/bounce-ascent
./verify_project.sh
/snap/bin/godot-4 project.godot
# Press F5 in the editor
```

Have fun! 🎮
