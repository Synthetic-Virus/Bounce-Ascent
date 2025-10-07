# Export Instructions for Bounce Ascent

## Prerequisites

1. **Download Export Templates**
   - Open Godot Editor
   - Go to `Editor` → `Manage Export Templates`
   - Download the official export templates for Godot 4.3

## Exporting to Windows (.exe)

1. **Project Menu**
   - Go to `Project` → `Export`
   - Click `Add...` → `Windows Desktop`

2. **Configure Windows Export**
   - **Custom Template**: Use the downloaded export templates
   - **Export PCK/Zip**: Enable PCK encryption
   - **Encryption Key**: Generate a random 256-bit key (keep this secure!)
   - **Runnable**: Check this box
   - **Embedded PCK**: Check this box

3. **Encryption Settings** (Important for anti-cheat!)
   - Click on `Script` tab
   - Enable `Encrypt Exported Scripts`
   - This prevents easy decompilation

4. **Export**
   - Click `Export Project`
   - Choose output location
   - File name: `BounceAscent.exe`

## Exporting to Linux

1. **Add Linux Export Preset**
   - `Project` → `Export` → `Add...` → `Linux/X11`

2. **Configure Linux Export**
   - Same encryption settings as Windows
   - **Runnable**: Check this box
   - **Embedded PCK**: Check this box

3. **Export**
   - Export as `BounceAscent.x86_64` or similar

## Exporting to macOS

1. **Add macOS Export Preset**
   - `Project` → `Export` → `Add...` → `macOS`

2. **Configure macOS Export**
   - Same encryption settings
   - May need to sign the app for distribution

3. **Export**
   - Export as `.app` bundle

## Additional Security Settings

### Enable All Anti-Cheat Features

In the export settings:

1. **Optimize Code** (Under `Resources` tab)
   - This makes reverse engineering harder

2. **Encrypt Export PCK** (Under `Resources` tab)
   - Enter a strong encryption key
   - Save this key separately (you'll need it for updates)

3. **Script Encryption** (Under `Script` tab)
   - Enable script encryption
   - This encrypts all GDScript files

### Recommended Export Settings

```
Resources:
  - Export Mode: Export all resources in the project
  - Export PCK/Zip: Enabled
  - Encryption: Enabled
  - Encryption Key: [Generate 256-bit random key]

Script:
  - Script Export Mode: Compiled
  - Script Encryption Key: [Same as above]
```

## Testing Exports

After exporting:

1. **Test on clean machine** - Ensure the game runs without Godot installed
2. **Test save file security** - Try manually editing save files to verify they're encrypted
3. **Test profile integrity** - Verify that tampered save files are rejected
4. **Performance test** - Ensure encryption doesn't impact performance

## Distribution

The exported `.exe` (or platform equivalent) can be distributed standalone. The game will:
- Create save files in the user's data directory (`%APPDATA%` on Windows, `~/.local/share` on Linux)
- All save files are encrypted and validated
- Anti-cheat measures are compiled into the executable

## Notes

- Save files are located in the user directory under `BounceAscent/`
- Profile data is encrypted and signed to prevent tampering
- The game validates save file integrity on load
- Export templates must match your Godot version exactly (4.3)
