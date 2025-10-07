# Quick Start Guide

## Running the Game in Development

### Option 1: Using Godot Editor (Recommended)

1. **Open the project in Godot**:
   ```bash
   cd bounce-ascent
   godot-4 project.godot
   ```

2. **Run the game**:
   - Press `F5` in the Godot Editor, or
   - Click the "Play" button in the top-right corner

### Option 2: Headless Run (Command Line)

```bash
cd bounce-ascent
godot-4 --path . res://scenes/MainMenu.tscn
```

## First Time Setup

When you first run the game:

1. A default profile will be created automatically
2. Your save file will be stored in:
   - **Linux**: `~/.local/share/godot/app_userdata/Bounce Ascent/profile.save`
   - **Windows**: `%APPDATA%/Godot/app_userdata/Bounce Ascent/profile.save`
   - **macOS**: `~/Library/Application Support/Godot/app_userdata/Bounce Ascent/profile.save`

## Gameplay Tips

1. **Don't fall behind!** - The camera scrolls down continuously
2. **Use manual jumps strategically** - You can force a jump, but there's a cooldown
3. **Watch for platform types**:
   - Red platforms break after one use
   - Purple platforms disappear after a short time
   - Yellow platforms move horizontally
4. **Stay within bounds** - You can't go off the sides of the screen
5. **Practice makes perfect** - The difficulty increases gradually

## Customizing Your Profile

To change your player name, you'll need to edit the default profile creation in:
- `scripts/GameManager.gd` → `create_default_profile()` function
- Change `"username": "Player"` to your desired name
- Delete the existing `profile.save` file to force creation of a new profile

## Troubleshooting

### Game won't start
- Make sure Godot 4.3 (or compatible version) is installed
- Check that all script files are in the `scripts/` directory
- Verify `GameManager.gd` is set as an autoload in `project.godot`

### Save file issues
- Delete the `profile.save` file to start fresh
- Check file permissions in the user data directory

### Performance issues
- The CRT shader can be resource-intensive
- To disable it, comment out `add_crt_shader()` in `scripts/Game.gd`

## Development Notes

### Testing Anti-Cheat

To verify save file encryption is working:

1. Play a game and achieve a score
2. Locate your `profile.save` file
3. Try opening it in a text editor - it should be encrypted/unreadable
4. Try editing it - the game should reject the modified file on next load

### Adjusting Difficulty

Edit `scripts/PlatformSpawner.gd`:
- Modify `TIER_X_HEIGHT` constants to change when new mechanics appear
- Adjust `INITIAL_VERTICAL_SPACING` to change platform density
- Change platform width ranges for easier/harder gameplay

Edit `scripts/GameCamera.gd`:
- Modify `INITIAL_SCROLL_SPEED` and `MAX_SCROLL_SPEED` for pacing
- Adjust `SPEED_INCREASE_RATE` for difficulty curve

### Adjusting Player Physics

Edit `scripts/Player.gd`:
- `JUMP_VELOCITY`: How high the ball jumps
- `MOVE_SPEED`: Horizontal movement speed
- `AUTO_JUMP_INTERVAL`: Time between automatic jumps
