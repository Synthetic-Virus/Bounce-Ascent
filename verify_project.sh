#!/bin/bash

# Verification script for Bounce Ascent project

echo "=== Bounce Ascent Project Verification ==="
echo ""

# Check if Godot is installed
echo "Checking Godot installation..."
if command -v /snap/bin/godot-4 &> /dev/null; then
    echo "✓ Godot 4 found: $(/snap/bin/godot-4 --version 2>&1 | head -n 1)"
elif command -v godot-4 &> /dev/null; then
    echo "✓ Godot 4 found: $(godot-4 --version 2>&1 | head -n 1)"
elif command -v godot &> /dev/null; then
    echo "✓ Godot found: $(godot --version 2>&1 | head -n 1)"
else
    echo "✗ Godot not found! Install it first."
    exit 1
fi
echo ""

# Check project structure
echo "Checking project structure..."
required_files=(
    "project.godot"
    "icon.svg"
    "export_presets.cfg"
    "scenes/MainMenu.tscn"
    "scenes/Game.tscn"
    "scenes/GameOver.tscn"
    "scripts/GameManager.gd"
    "scripts/Player.gd"
    "scripts/Platform.gd"
    "scripts/MovingPlatform.gd"
    "scripts/BreakablePlatform.gd"
    "scripts/TemporaryPlatform.gd"
    "scripts/PlatformSpawner.gd"
    "scripts/GameCamera.gd"
    "scripts/GameUI.gd"
    "scripts/Game.gd"
    "scripts/MainMenu.gd"
    "scripts/GameOver.gd"
    "resources/shaders/crt_shader.gdshader"
)

missing_files=0
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file"
    else
        echo "✗ Missing: $file"
        ((missing_files++))
    fi
done
echo ""

if [ $missing_files -gt 0 ]; then
    echo "✗ Project incomplete! $missing_files files missing."
    exit 1
fi

echo "=== Project Structure: OK ==="
echo ""

# Count lines of code
echo "=== Code Statistics ==="
echo "GDScript files: $(find scripts/ -name "*.gd" | wc -l)"
echo "Scene files: $(find scenes/ -name "*.tscn" | wc -l)"
echo "Shader files: $(find resources/ -name "*.gdshader" 2>/dev/null | wc -l)"
echo "Total GDScript lines: $(find scripts/ -name "*.gd" -exec cat {} \; | wc -l)"
echo ""

# Check documentation
echo "=== Documentation ==="
docs=(
    "README.md"
    "QUICKSTART.md"
    "EXPORT_INSTRUCTIONS.md"
    "PROJECT_SUMMARY.md"
)

for doc in "${docs[@]}"; do
    if [ -f "$doc" ]; then
        echo "✓ $doc"
    else
        echo "✗ Missing: $doc"
    fi
done
echo ""

echo "=== Verification Complete ==="
echo ""
echo "To run the game in Godot Editor:"
echo "  /snap/bin/godot-4 project.godot"
echo ""
echo "To run headless (from project directory):"
echo "  /snap/bin/godot-4 --path . res://scenes/MainMenu.tscn"
echo ""
echo "Project is ready for development and testing!"
