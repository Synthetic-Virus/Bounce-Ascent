# Windows Defender Warning - How to Run the Game

## Why Does Windows Defender Warn About This Game?

Windows Defender (SmartScreen) shows warnings for **unsigned executables** from unknown publishers. This is a security feature that protects against malware.

**This game is safe!** The warning appears because:
1. The .exe is not digitally signed with a code signing certificate
2. It's a new/unknown file that hasn't been downloaded by many users yet
3. It was compiled locally rather than from a verified publisher

## How to Run the Game Safely

### Option 1: Click "More info" → "Run anyway" (Recommended)

When you double-click the .exe and see the warning:

1. Click **"More info"** (small link in the warning dialog)
2. Click **"Run anyway"** button that appears
3. The game will start and won't warn again for this file

### Option 2: Add Exception in Windows Security

1. Open **Windows Security** (search in Start menu)
2. Go to **Virus & threat protection**
3. Click **Manage settings** under "Virus & threat protection settings"
4. Scroll down to **Exclusions**
5. Click **Add or remove exclusions**
6. Click **Add an exclusion** → **Folder**
7. Select your Desktop folder (or wherever you put the .exe)
8. The game will now run without warnings

### Option 3: Scan with Windows Defender First

1. Right-click **BounceAscent.exe**
2. Select **Scan with Microsoft Defender**
3. Wait for scan to complete (it will show "No threats found")
4. Run the game normally

## Why Not Sign the Executable?

Code signing certificates cost $100-500+ per year and require:
- Legal business entity
- Identity verification
- Annual renewal fees

For a free, open-source game project, this isn't practical.

## Is This Game Really Safe?

**Yes!** Here's how to verify:

1. **Source Code**: The entire game is open source on GitHub
   - You can read all the code
   - No hidden malicious code
   - Built with Godot Engine (trusted game engine)

2. **Scan It**: Use any antivirus to scan the .exe
   - Windows Defender
   - VirusTotal (upload to virustotal.com)
   - Your preferred antivirus

3. **Build It Yourself**: If you're technical:
   - Clone the GitHub repository
   - Open in Godot Engine
   - Export the .exe yourself
   - You'll see it's identical code

## What Does This Game Do?

The executable:
- ✅ Runs the game (no installation needed)
- ✅ Creates encrypted save files in: `%APPDATA%\Godot\app_userdata\Bounce Ascent\`
- ❌ Does NOT access the internet
- ❌ Does NOT modify system files
- ❌ Does NOT install anything
- ❌ Does NOT run in background when closed

## Alternative: Build Your Own Executable

If you're still concerned:

1. Install Godot Engine 4.3+ from godotengine.org
2. Clone this repository
3. Open the project in Godot
4. Export as Windows Desktop
5. You'll have your own .exe that you built yourself!

See `EXPORT_INSTRUCTIONS.md` for details.

## For Advanced Users: Code Signing (Optional)

If you want to sign the executable yourself:

1. Purchase a code signing certificate from a Certificate Authority
2. Use `signtool.exe` (Windows SDK):
   ```cmd
   signtool sign /f MyCert.pfx /p password /t http://timestamp.digicert.com BounceAscent.exe
   ```
3. The warning will disappear

## Common Questions

**Q: Will this warning go away over time?**
A: Potentially, if enough people download and run the game, SmartScreen may eventually recognize it as safe. But this takes many downloads over time.

**Q: Is this warning different from a virus detection?**
A: Yes! SmartScreen warnings say "unknown publisher" or "unrecognized app". Virus warnings say "Threat detected" with a specific virus name. This game only triggers SmartScreen (unknown publisher), not virus detection.

**Q: Can I get a virus from running this?**
A: No. The source code is public and auditable. The game is built with Godot Engine, a trusted open-source game engine used by thousands of developers.

**Q: Why not just use a different game engine?**
A: This warning appears for ANY unsigned executable, regardless of the tool used to create it. Unity, Unreal, GameMaker, etc. all have the same issue if you don't pay for code signing.

## Summary

✅ **The game is safe**
✅ **The warning is normal for unsigned software**
✅ **Click "More info" → "Run anyway"**
✅ **Or scan it yourself to verify**
✅ **Source code is public on GitHub**

This is a common limitation of distributing free software on Windows without paying for a code signing certificate.

---

**Still have concerns?** Check the source code on GitHub or build the .exe yourself!
