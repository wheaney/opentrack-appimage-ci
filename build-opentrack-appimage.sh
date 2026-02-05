#!/bin/bash
set -e

# OpenTrack AppImage Builder (CPU-only with ONNX Runtime)
# This script builds an AppImage from your existing OpenTrack installation

# Configuration - ADJUST THESE TO MATCH YOUR SETUP
OPENTRACK_BUILD_DIR="${OPENTRACK_BUILD_DIR:-$HOME/opentrack/build}"
OPENTRACK_INSTALL_DIR="${OPENTRACK_INSTALL_DIR:-$HOME/opentrack/install}"
ONNX_RUNTIME_DIR="${ONNX_RUNTIME_DIR:-/usr/local}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/appimage-output}"

# AppImage tools
LINUXDEPLOY_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
LINUXDEPLOY_QT_URL="https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage"

echo "=== OpenTrack AppImage Builder ==="
echo "OpenTrack install dir: $OPENTRACK_INSTALL_DIR"
echo "ONNX Runtime dir: $ONNX_RUNTIME_DIR"
echo "Output dir: $OUTPUT_DIR"
echo ""

# Create working directory
WORK_DIR=$(mktemp -d)
echo "Working in: $WORK_DIR"

cd "$WORK_DIR"

# Download linuxdeploy tools if needed
if [ ! -f "$HOME/.local/bin/linuxdeploy-x86_64.AppImage" ]; then
    echo "Downloading linuxdeploy..."
    mkdir -p "$HOME/.local/bin"
    wget -q "$LINUXDEPLOY_URL" -O "$HOME/.local/bin/linuxdeploy-x86_64.AppImage"
    chmod +x "$HOME/.local/bin/linuxdeploy-x86_64.AppImage"
fi

if [ ! -f "$HOME/.local/bin/linuxdeploy-plugin-qt-x86_64.AppImage" ]; then
    echo "Downloading linuxdeploy-plugin-qt..."
    wget -q "$LINUXDEPLOY_QT_URL" -O "$HOME/.local/bin/linuxdeploy-plugin-qt-x86_64.AppImage"
    chmod +x "$HOME/.local/bin/linuxdeploy-plugin-qt-x86_64.AppImage"
fi

export PATH="$HOME/.local/bin:$PATH"

# Create AppDir structure
APPDIR="$WORK_DIR/AppDir"
mkdir -p "$APPDIR"

echo "Copying OpenTrack installation..."
# Copy OpenTrack files
if [ -d "$OPENTRACK_INSTALL_DIR" ]; then
    cp -r "$OPENTRACK_INSTALL_DIR"/* "$APPDIR/"
elif [ -d "$OPENTRACK_BUILD_DIR" ]; then
    # If no install dir, try to use build dir directly
    echo "No install dir found, using build dir"
    make -C "$OPENTRACK_BUILD_DIR" DESTDIR="$APPDIR" install
else
    echo "ERROR: Could not find OpenTrack installation or build directory"
    exit 1
fi

# Find and copy ONNX Runtime libraries
echo "Searching for ONNX Runtime libraries..."
ONNX_LIB_DIRS=(
    "$ONNX_RUNTIME_DIR/lib"
    "$ONNX_RUNTIME_DIR/lib64"
    "/usr/lib"
    "/usr/lib64"
    "/usr/lib/x86_64-linux-gnu"
    "/usr/local/lib"
)

mkdir -p "$APPDIR/usr/lib"

for dir in "${ONNX_LIB_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        # Copy ONNX Runtime shared libraries
        find "$dir" -maxdepth 1 -name "libonnxruntime*.so*" -exec cp -v {} "$APPDIR/usr/lib/" \; 2>/dev/null || true
    fi
done

# Verify we found ONNX Runtime
if ! ls "$APPDIR/usr/lib/libonnxruntime"*.so* 1> /dev/null 2>&1; then
    echo "WARNING: Could not find ONNX Runtime libraries. Searching more broadly..."
    find /usr -name "libonnxruntime*.so*" 2>/dev/null | head -5
    echo "Please set ONNX_RUNTIME_DIR to the correct location"
fi

# Create desktop entry
cat > "$APPDIR/opentrack.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=OpenTrack
Comment=Head tracking software
Exec=opentrack
Icon=opentrack
Categories=Utility;Game;
EOF

# Find opentrack icon
ICON_FOUND=false
for ext in png svg xpm; do
    if find "$APPDIR" -name "opentrack.$ext" | grep -q .; then
        ICON_PATH=$(find "$APPDIR" -name "opentrack.$ext" | head -1)
        cp "$ICON_PATH" "$APPDIR/opentrack.$ext"
        ICON_FOUND=true
        break
    fi
done

if [ "$ICON_FOUND" = false ]; then
    echo "WARNING: Could not find opentrack icon, creating placeholder"
    # Create a simple placeholder icon
    convert -size 256x256 xc:blue -pointsize 72 -fill white -gravity center \
            -annotate +0+0 'OT' "$APPDIR/opentrack.png" 2>/dev/null || \
    echo "Could not create placeholder icon (imagemagick not installed)"
fi

# Create AppRun wrapper to set up environment
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}

# Add our lib directory to library path
export LD_LIBRARY_PATH="$HERE/usr/lib:$HERE/usr/lib64:$LD_LIBRARY_PATH"

# Set up Qt plugin path
export QT_PLUGIN_PATH="$HERE/usr/plugins:$QT_PLUGIN_PATH"

# Run opentrack
exec "$HERE/usr/bin/opentrack" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Ensure opentrack binary exists in expected location
if [ ! -f "$APPDIR/usr/bin/opentrack" ]; then
    # Try to find it
    OPENTRACK_BIN=$(find "$APPDIR" -name "opentrack" -type f -executable | head -1)
    if [ -n "$OPENTRACK_BIN" ]; then
        mkdir -p "$APPDIR/usr/bin"
        cp "$OPENTRACK_BIN" "$APPDIR/usr/bin/opentrack"
    else
        echo "ERROR: Could not find opentrack executable"
        exit 1
    fi
fi

# Run linuxdeploy to bundle dependencies
echo "Running linuxdeploy to bundle dependencies..."
export OUTPUT="$OUTPUT_DIR/OpenTrack-x86_64.AppImage"
mkdir -p "$OUTPUT_DIR"

linuxdeploy-x86_64.AppImage \
    --appdir="$APPDIR" \
    --plugin=qt \
    --output=appimage

# Move AppImage to output directory if it wasn't created there
if [ -f "$WORK_DIR/OpenTrack-x86_64.AppImage" ]; then
    mv "$WORK_DIR/OpenTrack-x86_64.AppImage" "$OUTPUT"
fi

echo ""
echo "=== Build Complete ==="
echo "AppImage created at: $OUTPUT"
echo ""
echo "To test:"
echo "  chmod +x $OUTPUT"
echo "  $OUTPUT"
echo ""
echo "Cleaning up temporary directory: $WORK_DIR"
rm -rf "$WORK_DIR"
