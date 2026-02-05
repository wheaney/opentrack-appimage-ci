#!/bin/bash
# Local test script to validate the build process works
# This mimics what the CI will do, useful for debugging

set -euo pipefail

echo "=== OpenTrack AppImage Local Build Test ==="
echo ""

# Configuration
OPENTRACK_REPO="opentrack/opentrack"
ONNX_REPO="microsoft/onnxruntime"

github_latest_release_tag() {
    local repo="$1"
    local api_url="https://api.github.com/repos/${repo}/releases/latest"
    local response

    # Optional: set GITHUB_TOKEN to increase rate limits.
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        response="$(wget -qO- \
            --header='Accept: application/vnd.github+json' \
            --header='User-Agent: opentrack-appimage-repo-test-build' \
            --header="Authorization: Bearer ${GITHUB_TOKEN}" \
            "$api_url")" || {
            echo "Failed to query GitHub API for ${repo} (auth)." >&2
            return 1
        }
    else
        response="$(wget -qO- \
            --header='Accept: application/vnd.github+json' \
            --header='User-Agent: opentrack-appimage-repo-test-build' \
            "$api_url")" || {
            echo "Failed to query GitHub API for ${repo}." >&2
            return 1
        }
    fi

    if [ -z "$response" ]; then
        echo "Empty response from GitHub API for ${repo}." >&2
        echo "Tip: export GITHUB_TOKEN=... to avoid rate limits." >&2
        return 1
    fi

    if command -v jq >/dev/null 2>&1; then
        local tag
        tag="$(printf '%s' "$response" | jq -r '.tag_name // empty')" || return 1
        if [ -n "$tag" ]; then
            printf '%s\n' "$tag"
            return 0
        fi

        local api_message
        api_message="$(printf '%s' "$response" | jq -r '.message // empty' 2>/dev/null || true)"
        if [ -n "$api_message" ]; then
            echo "GitHub API error for ${repo}: ${api_message}" >&2
        else
            echo "Could not find tag_name in GitHub API response for ${repo}." >&2
        fi
        return 2
    fi

    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "$response" | python3 - <<'PY'
import json, sys
data = json.load(sys.stdin)
tag = data.get('tag_name')
if not tag:
    raise SystemExit(2)
print(tag)
PY
        return $?
    fi

    printf '%s' "$response" \
        | sed -nE 's/^[[:space:]]*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
        | head -n1
}

# Allow manual overrides:
# - Arg1: OPENTRACK version/tag (e.g. "opentrack-2.3.14" or "latest")
# - Env: ONNX_VERSION (e.g. "1.17.1" or "latest")
OPENTRACK_VERSION="latest"
ONNX_VERSION="latest"

if [ "$OPENTRACK_VERSION" = "latest" ]; then
    echo "Resolving latest stable OpenTrack release tag..."
    OPENTRACK_VERSION="$(github_latest_release_tag "$OPENTRACK_REPO")"
fi

if [ "$ONNX_VERSION" = "latest" ]; then
    echo "Resolving latest stable ONNX Runtime release tag..."
    ONNX_VERSION="$(github_latest_release_tag "$ONNX_REPO")"
    ONNX_VERSION="${ONNX_VERSION#v}"
fi

echo "Building OpenTrack version: $OPENTRACK_VERSION"
echo "Using ONNX Runtime version: $ONNX_VERSION"
echo ""

# Check dependencies
echo "Checking dependencies..."
MISSING_DEPS=()

command -v cmake >/dev/null 2>&1 || MISSING_DEPS+=("cmake")
command -v git >/dev/null 2>&1 || MISSING_DEPS+=("git")
command -v wget >/dev/null 2>&1 || MISSING_DEPS+=("wget")
command -v objcopy >/dev/null 2>&1 || MISSING_DEPS+=("objcopy (binutils)")
if ! command -v qmake >/dev/null 2>&1 && ! command -v qmake6 >/dev/null 2>&1 && ! command -v qt6-qmake >/dev/null 2>&1; then
    MISSING_DEPS+=("qmake (Qt5) or qmake6 (Qt6)")
fi

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo "Missing dependencies: ${MISSING_DEPS[*]}"
    echo "Install with: sudo apt-get install ${MISSING_DEPS[*]}"
    exit 1
fi

echo "✓ All dependencies found"
echo ""

# Create (or reuse) build directory
REUSE_BUILD_DIR=0
if [ -n "${BUILD_DIR:-}" ]; then
    REUSE_BUILD_DIR=1
    if [ ! -d "$BUILD_DIR" ]; then
        echo "BUILD_DIR was set but does not exist: $BUILD_DIR" >&2
        exit 1
    fi
else
    BUILD_DIR=$(mktemp -d -t opentrack-build-XXXXXX)
fi

cd "$BUILD_DIR"
echo "Working in: $BUILD_DIR"

ONNX_DIR="$BUILD_DIR/onnxruntime-linux-x64-${ONNX_VERSION}"
OPENTRACK_DIR="$BUILD_DIR/opentrack"

if [ "$REUSE_BUILD_DIR" -eq 1 ]; then
    echo "Reusing BUILD_DIR; skipping downloads and repo checkout"

    if [ ! -d "$ONNX_DIR" ]; then
        echo "Expected ONNX Runtime directory not found: $ONNX_DIR" >&2
        echo "Either unset BUILD_DIR or place the extracted ONNX Runtime there." >&2
        exit 1
    fi

    if [ ! -d "$OPENTRACK_DIR/.git" ]; then
        echo "Expected OpenTrack git checkout not found: $OPENTRACK_DIR" >&2
        echo "Either unset BUILD_DIR or clone the repo into that directory." >&2
        exit 1
    fi

    echo "✓ Using existing ONNX Runtime and OpenTrack checkout"
    echo ""
else
    # Download ONNX Runtime
    echo "Downloading ONNX Runtime..."
    wget -q --show-progress https://github.com/microsoft/onnxruntime/releases/download/v${ONNX_VERSION}/onnxruntime-linux-x64-${ONNX_VERSION}.tgz
    tar xzf onnxruntime-linux-x64-${ONNX_VERSION}.tgz
    echo "✓ ONNX Runtime ready"
    echo ""

    # Clone OpenTrack
    echo "Cloning OpenTrack..."
    git clone --depth 1 --branch "$OPENTRACK_VERSION" https://github.com/opentrack/opentrack.git
    echo "✓ OpenTrack cloned"
    echo ""
fi

cd "$OPENTRACK_DIR"

# Build OpenTrack
echo "Building OpenTrack..."
mkdir -p build
cd build

# Workaround: recent GCC versions reject converting QLibrary::resolve()'s
# QFunctionPointer return to void* in OpenTrack's tracker-neuralnet code.
# Without modifying OpenTrack sources, GCC's -fpermissive allows this.
#
# Controls:
# - OPENTRACK_FPERMISSIVE=1|0|auto (default: 1)
#   - 1: always add -fpermissive when using GCC
#   - 0: never add -fpermissive
#   - auto: add -fpermissive for newer GCC versions only
# - OPENTRACK_EXTRA_CXX_FLAGS="..." (additional flags to append)
OPENTRACK_FPERMISSIVE="${OPENTRACK_FPERMISSIVE:-1}"
OPENTRACK_EXTRA_CXX_FLAGS="${OPENTRACK_EXTRA_CXX_FLAGS:-}"
OPENTRACK_EXTRA_C_FLAGS="${OPENTRACK_EXTRA_C_FLAGS:-}"
OPENTRACK_EXTRA_LD_FLAGS="${OPENTRACK_EXTRA_LD_FLAGS:-}"

# Portability: OpenTrack's build system enables -march=native in Release builds.
# That can produce binaries requiring AVX-512, etc., which then fail on Steam
# Deck with: "CPU ISA level is lower than required".
#
# This script always enforces a portable baseline by default.
# Override the baseline explicitly if you know what you're doing:
#   OPENTRACK_PORTABLE_FLAGS="-march=x86-64-v3 -mtune=generic" ./test-build.sh
OPENTRACK_PORTABLE_FLAGS="${OPENTRACK_PORTABLE_FLAGS:--march=x86-64-v2 -mtune=generic}"
OPENTRACK_PORTABLE_CXX_FLAGS="$OPENTRACK_PORTABLE_FLAGS"
OPENTRACK_PORTABLE_C_FLAGS="$OPENTRACK_PORTABLE_FLAGS"

# Some toolchains/distros emit GNU_PROPERTY_X86_ISA_1_NEEDED notes that can
# incorrectly mark the resulting ELF as requiring x86-64-v4 (AVX-512). Steam
# Deck does not support AVX-512, and glibc's loader will refuse to start with:
#   "CPU ISA level is lower than required"
#
# Force the linker to mark outputs as needing at most x86-64-v2.
# Override if needed:
#   OPENTRACK_PORTABLE_LD_FLAGS="-Wl,-z,x86-64-v3" ./test-build.sh
OPENTRACK_PORTABLE_LD_FLAGS="${OPENTRACK_PORTABLE_LD_FLAGS:--Wl,-z,x86-64-v2}"

if [ "$OPENTRACK_FPERMISSIVE" != "0" ]; then
    cxx_first_line="$(c++ --version 2>/dev/null | head -n 1 || true)"
    if printf '%s' "$cxx_first_line" | grep -qiE '(g\+\+|gcc)'; then
        cxx_major="$(c++ -dumpversion 2>/dev/null | cut -d. -f1 || true)"
        if [ "$OPENTRACK_FPERMISSIVE" = "1" ] || { [ "$OPENTRACK_FPERMISSIVE" = "auto" ] && [ -n "$cxx_major" ] && [ "$cxx_major" -ge 15 ]; }; then
            OPENTRACK_EXTRA_CXX_FLAGS="${OPENTRACK_EXTRA_CXX_FLAGS:+$OPENTRACK_EXTRA_CXX_FLAGS }-fpermissive"
        fi
    fi
fi

if [ -n "$OPENTRACK_EXTRA_CXX_FLAGS" ]; then
    echo "Using extra CXX flags: $OPENTRACK_EXTRA_CXX_FLAGS"
fi

if [ -n "$OPENTRACK_EXTRA_C_FLAGS" ]; then
    echo "Using extra C flags: $OPENTRACK_EXTRA_C_FLAGS"
fi

echo "Using portable baseline flags: $OPENTRACK_PORTABLE_FLAGS"
echo "Using portable linker flags: $OPENTRACK_PORTABLE_LD_FLAGS"

# OpenTrack's CMake forcibly overwrites CMAKE_{C,CXX}_FLAGS{,_RELEASE} (including
# -march=native) unless __otr_compile_flags_set is already set.
#
# To keep the build portable and to inject -fpermissive reliably (without
# patching upstream sources), we pre-set that cache variable and provide our own
# flags explicitly.
OTR_WARN_FLAGS="-ggdb -Wall -Wextra -Wpedantic"
OTR_CMAKE_C_FLAGS="$OTR_WARN_FLAGS${OPENTRACK_EXTRA_C_FLAGS:+ $OPENTRACK_EXTRA_C_FLAGS}"
OTR_CMAKE_CXX_FLAGS="$OTR_WARN_FLAGS${OPENTRACK_EXTRA_CXX_FLAGS:+ $OPENTRACK_EXTRA_CXX_FLAGS}"
OTR_CMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG${OPENTRACK_PORTABLE_C_FLAGS:+ $OPENTRACK_PORTABLE_C_FLAGS}${OPENTRACK_EXTRA_C_FLAGS:+ $OPENTRACK_EXTRA_C_FLAGS}"
OTR_CMAKE_CXX_FLAGS_RELEASE="-O3 -DNDEBUG${OPENTRACK_PORTABLE_CXX_FLAGS:+ $OPENTRACK_PORTABLE_CXX_FLAGS}${OPENTRACK_EXTRA_CXX_FLAGS:+ $OPENTRACK_EXTRA_CXX_FLAGS}"

OTR_CMAKE_EXE_LINKER_FLAGS="$OPENTRACK_PORTABLE_LD_FLAGS${OPENTRACK_EXTRA_LD_FLAGS:+ $OPENTRACK_EXTRA_LD_FLAGS}"
OTR_CMAKE_SHARED_LINKER_FLAGS="$OPENTRACK_PORTABLE_LD_FLAGS${OPENTRACK_EXTRA_LD_FLAGS:+ $OPENTRACK_EXTRA_LD_FLAGS}"
OTR_CMAKE_MODULE_LINKER_FLAGS="$OPENTRACK_PORTABLE_LD_FLAGS${OPENTRACK_EXTRA_LD_FLAGS:+ $OPENTRACK_EXTRA_LD_FLAGS}"

echo "Using CMake C flags: $OTR_CMAKE_C_FLAGS"
echo "Using CMake CXX flags: $OTR_CMAKE_CXX_FLAGS"
echo "Using CMake C Release flags: $OTR_CMAKE_C_FLAGS_RELEASE"
echo "Using CMake CXX Release flags: $OTR_CMAKE_CXX_FLAGS_RELEASE"
echo "Using CMake EXE linker flags: $OTR_CMAKE_EXE_LINKER_FLAGS"
echo "Using CMake SHARED linker flags: $OTR_CMAKE_SHARED_LINKER_FLAGS"
echo "Using CMake MODULE linker flags: $OTR_CMAKE_MODULE_LINKER_FLAGS"

CMAKE_ARGS=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX=/usr
    -DSDK_ENABLE_LIBEVDEV=OFF
    "-DONNXRuntime_DIR=$ONNX_DIR"
    -D__otr_compile_flags_set=TRUE
    "-DCMAKE_C_FLAGS=$OTR_CMAKE_C_FLAGS"
    "-DCMAKE_CXX_FLAGS=$OTR_CMAKE_CXX_FLAGS"
    "-DCMAKE_C_FLAGS_RELEASE=$OTR_CMAKE_C_FLAGS_RELEASE"
    "-DCMAKE_CXX_FLAGS_RELEASE=$OTR_CMAKE_CXX_FLAGS_RELEASE"
    "-DCMAKE_EXE_LINKER_FLAGS=$OTR_CMAKE_EXE_LINKER_FLAGS"
    "-DCMAKE_SHARED_LINKER_FLAGS=$OTR_CMAKE_SHARED_LINKER_FLAGS"
    "-DCMAKE_MODULE_LINKER_FLAGS=$OTR_CMAKE_MODULE_LINKER_FLAGS"
    "-DCMAKE_EXE_LINKER_FLAGS_RELEASE=$OTR_CMAKE_EXE_LINKER_FLAGS"
    "-DCMAKE_SHARED_LINKER_FLAGS_RELEASE=$OTR_CMAKE_SHARED_LINKER_FLAGS"
    "-DCMAKE_MODULE_LINKER_FLAGS_RELEASE=$OTR_CMAKE_MODULE_LINKER_FLAGS"
)

# If re-running in an existing build directory, the CMakeCache can preserve the
# upstream forced -march=native. Clear the cache when we detect it so our
# portability flags apply.
if [ -f CMakeCache.txt ] && grep -q -- "-march=native" CMakeCache.txt; then
    echo "CMake cache contains -march=native; clearing cache to enforce portability"
    rm -f CMakeCache.txt
    rm -rf CMakeFiles
fi

# If re-running in an existing build directory from before we forced the linker
# ISA note, clear the cache so the new linker flags take effect.
if [ -f CMakeCache.txt ] && ! grep -q -- "-z,x86-64-v2" CMakeCache.txt; then
    echo "CMake cache does not include portable linker ISA note; clearing cache"
    rm -f CMakeCache.txt
    rm -rf CMakeFiles
fi

cmake .. "${CMAKE_ARGS[@]}"

BUILD_LOG="$BUILD_DIR/opentrack-build.log"
echo "Running make (logging to: $BUILD_LOG)"
if ! make --output-sync=target -j"$(nproc)" 2>&1 | tee "$BUILD_LOG"; then
    echo ""
    echo "✗ Build failed (see full log: $BUILD_LOG)"
    echo "--- First error lines (if any) ---"
    grep -nE '(^|[[:space:]:])error:' "$BUILD_LOG" | head -n 50 || true
    echo "--- Last 120 lines ---"
    tail -n 120 "$BUILD_LOG" || true
    exit 2
fi
echo "✓ OpenTrack built successfully"
echo ""

# Install to AppDir
echo "Creating AppDir..."
APPDIR="$BUILD_DIR/AppDir"
DESTDIR="$APPDIR" make install

remove_note_gnu_property() {
    local elf="$1"
    if [ ! -f "$elf" ]; then
        return 0
    fi
    if ! command -v objcopy >/dev/null 2>&1; then
        return 0
    fi

    # CachyOS/this toolchain emits a GNU_PROPERTY_X86_ISA_1_NEEDED note that
    # marks binaries as requiring x86-64-v4, which makes Steam Deck refuse to
    # run them. Removing this note restores runtime compatibility.
    objcopy --remove-section .note.gnu.property "$elf" >/dev/null 2>&1 || true
}

echo "Sanitizing GNU property notes for portability..."
remove_note_gnu_property "$APPDIR/usr/bin/opentrack"
if [ -d "$APPDIR/usr/libexec/opentrack" ]; then
    while IFS= read -r -d '' f; do
        remove_note_gnu_property "$f"
    done < <(find "$APPDIR/usr/libexec/opentrack" -type f -name '*.so' -print0 2>/dev/null || true)
fi

assert_no_x86_64_v4_needed() {
    local elf="$1"
    if [ ! -f "$elf" ]; then
        return 0
    fi
    if ! command -v readelf >/dev/null 2>&1; then
        return 0
    fi

    # If this trips, Steam Deck (no AVX-512) will refuse to run the binary.
    if readelf -n "$elf" 2>/dev/null | grep -qE 'x86 ISA needed:.*x86-64-v4'; then
        echo "ERROR: $elf is marked as requiring x86-64-v4 (AVX-512)." >&2
        echo "This will fail on Steam Deck with: CPU ISA level is lower than required" >&2
        echo "Fix: rebuild with OPENTRACK_PORTABLE_LD_FLAGS='-Wl,-z,x86-64-v2' (default)" >&2
        echo "and ensure no environment LDFLAGS/CFLAGS override it." >&2
        echo "--- readelf notes ---" >&2
        readelf -n "$elf" 2>/dev/null | sed -n '1,120p' >&2 || true
        return 1
    fi
    return 0
}

assert_no_x86_64_v4_needed "$APPDIR/usr/bin/opentrack"

# Copy ONNX Runtime libs
mkdir -p "$APPDIR/usr/lib"
cp -v "$ONNX_DIR"/lib/libonnxruntime.so* "$APPDIR/usr/lib/"

# OpenTrack's neuralnet tracker loads a small loader library at runtime:
#   /usr/libexec/opentrack/onnxruntime.so
# That loader expects to find libonnxruntime.so next to it (typically via
# $ORIGIN). Always place a copy there to ensure the AppImage can load ONNX.
mkdir -p "$APPDIR/usr/libexec/opentrack"
cp -v "$ONNX_DIR"/lib/libonnxruntime.so* "$APPDIR/usr/libexec/opentrack/"
echo "✓ AppDir prepared"
echo ""

# Download linuxdeploy
echo "Downloading linuxdeploy..."
cd "$BUILD_DIR"

wget -q https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
wget -q https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage

chmod +x linuxdeploy*.AppImage
echo "✓ linuxdeploy ready"
echo ""

# Create desktop file if needed
if [ ! -f "$APPDIR/usr/share/applications/opentrack.desktop" ]; then
    echo "Creating desktop file..."
    mkdir -p "$APPDIR/usr/share/applications"
    cat > "$APPDIR/usr/share/applications/opentrack.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=OpenTrack
GenericName=Head Tracking
Comment=Head tracking software with neural network support
Exec=opentrack
Icon=opentrack
Categories=Utility;Game;
Terminal=false
EOF
fi

# linuxdeploy requires an icon file matching the desktop file's Icon= entry.
# Ensure there's an icon available in the AppDir root, falling back to a simple
# generated SVG if none is installed by the build.
ICON_NAME="opentrack"
ICON_FILE=""

find_first_icon() {
    local base="$1"
    # Prefer scalable/vector icons, then PNG from common locations
    for pattern in \
        "$base/usr/share/icons/hicolor/scalable/apps/${ICON_NAME}.svg" \
        "$base/usr/share/icons/hicolor"/*/apps/"${ICON_NAME}.png" \
        "$base/usr/share/pixmaps/${ICON_NAME}.png" \
        "$base/usr/share/pixmaps/${ICON_NAME}.svg"; do
        if ls $pattern >/dev/null 2>&1; then
            # shellcheck disable=SC2086
            echo $pattern | head -n1
            return 0
        fi
    done
    return 1
}

if ICON_FILE_CANDIDATE="$(find_first_icon "$APPDIR" 2>/dev/null || true)"; then
    if [ -n "$ICON_FILE_CANDIDATE" ]; then
        case "$ICON_FILE_CANDIDATE" in
            *.svg) ICON_FILE="$APPDIR/${ICON_NAME}.svg" ;;
            *.png) ICON_FILE="$APPDIR/${ICON_NAME}.png" ;;
        esac
        if [ -n "$ICON_FILE" ]; then
            if [ -e "$ICON_FILE" ] && [ "$ICON_FILE_CANDIDATE" -ef "$ICON_FILE" ]; then
                : # already in place
            else
                cp -f "$ICON_FILE_CANDIDATE" "$ICON_FILE"
            fi
        fi
    fi
fi

if [ -z "$ICON_FILE" ] || [ ! -f "$ICON_FILE" ]; then
    ICON_FILE="$APPDIR/${ICON_NAME}.svg"
    cat > "$ICON_FILE" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="48" fill="#1f2937"/>
  <circle cx="128" cy="128" r="72" fill="#111827" stroke="#60a5fa" stroke-width="12"/>
  <path d="M96 132c16-28 48-28 64 0" fill="none" stroke="#60a5fa" stroke-width="12" stroke-linecap="round"/>
  <circle cx="104" cy="108" r="10" fill="#60a5fa"/>
  <circle cx="152" cy="108" r="10" fill="#60a5fa"/>
</svg>
EOF
fi

echo "Using icon file: $ICON_FILE"

# Build AppImage
echo "Building AppImage..."
export VERSION="${OPENTRACK_VERSION#opentrack-}"

# linuxdeploy-plugin-qt uses qmake to discover Qt plugin/module paths. When the
# Qt major version used to build OpenTrack doesn't match the default `qmake` in
# PATH (common on dev machines with both Qt5 and Qt6), the plugin may print
# "Could not find Qt modules to deploy".
#
# Auto-select qmake based on the Qt libraries bundled into the AppDir.
# Override with: LINUXDEPLOY_QMAKE=/path/to/qmake (or export QMAKE yourself).
LINUXDEPLOY_QMAKE="${LINUXDEPLOY_QMAKE:-}"

detect_qt_major_for_executable() {
    local exe="$1"
    if [ ! -x "$exe" ]; then
        return 1
    fi

    if command -v ldd >/dev/null 2>&1; then
        if ldd "$exe" 2>/dev/null | grep -qE 'libQt6(Core|Gui|Widgets)\.so'; then
            printf '6'
            return 0
        fi
        if ldd "$exe" 2>/dev/null | grep -qE 'libQt5(Core|Gui|Widgets)\.so'; then
            printf '5'
            return 0
        fi
    fi

    if command -v readelf >/dev/null 2>&1; then
        if readelf -d "$exe" 2>/dev/null | grep -qE 'NEEDED.*libQt6(Core|Gui|Widgets)\.so'; then
            printf '6'
            return 0
        fi
        if readelf -d "$exe" 2>/dev/null | grep -qE 'NEEDED.*libQt5(Core|Gui|Widgets)\.so'; then
            printf '5'
            return 0
        fi
    fi

    return 2
}

pick_qmake_for_qt_major() {
    local major="$1"
    if [ "$major" = "6" ]; then
        if command -v qmake6 >/dev/null 2>&1; then
            command -v qmake6
            return 0
        fi
        if command -v qt6-qmake >/dev/null 2>&1; then
            command -v qt6-qmake
            return 0
        fi
        if command -v qmake-qt6 >/dev/null 2>&1; then
            command -v qmake-qt6
            return 0
        fi
        return 1
    fi

    if [ "$major" = "5" ]; then
        if command -v qmake >/dev/null 2>&1; then
            command -v qmake
            return 0
        fi
        if command -v qmake5 >/dev/null 2>&1; then
            command -v qmake5
            return 0
        fi
        if command -v qmake-qt5 >/dev/null 2>&1; then
            command -v qmake-qt5
            return 0
        fi
        return 1
    fi

    return 2
}

if [ -z "${QMAKE:-}" ]; then
    if [ -n "$LINUXDEPLOY_QMAKE" ]; then
        export QMAKE="$LINUXDEPLOY_QMAKE"
    else
        qt_major="$(detect_qt_major_for_executable "$APPDIR/usr/bin/opentrack" 2>/dev/null || true)"
        if [ -n "$qt_major" ]; then
            if qmake_path="$(pick_qmake_for_qt_major "$qt_major" 2>/dev/null || true)"; then
                if [ -n "$qmake_path" ]; then
                    export QMAKE="$qmake_path"
                fi
            fi
        fi

        # Fallback to probing AppDir only if detection didn't work.
        if [ -z "${QMAKE:-}" ]; then
            if ls "$APPDIR/usr/lib"/libQt6Core.so.* >/dev/null 2>&1; then
                if qmake_path="$(pick_qmake_for_qt_major 6 2>/dev/null || true)"; then
                    export QMAKE="$qmake_path"
                fi
            elif ls "$APPDIR/usr/lib"/libQt5Core.so.* >/dev/null 2>&1; then
                if qmake_path="$(pick_qmake_for_qt_major 5 2>/dev/null || true)"; then
                    export QMAKE="$qmake_path"
                fi
            fi
        fi
    fi
fi

if [ -n "${QMAKE:-}" ]; then
    echo "linuxdeploy-plugin-qt: using QMAKE=$QMAKE"
else
    qt_major="$(detect_qt_major_for_executable "$APPDIR/usr/bin/opentrack" 2>/dev/null || true)"
    if [ "$qt_major" = "6" ]; then
        echo "linuxdeploy-plugin-qt: OpenTrack links against Qt6 but Qt6 qmake wasn't found." >&2
        echo "Install Qt6 qmake tools (e.g. ubuntu/debian: qt6-base-dev-tools) or set LINUXDEPLOY_QMAKE." >&2
        exit 1
    elif [ "$qt_major" = "5" ]; then
        echo "linuxdeploy-plugin-qt: OpenTrack links against Qt5 but Qt5 qmake wasn't found." >&2
        echo "Install Qt5 qmake tools (e.g. ubuntu/debian: qtbase5-dev qttools5-dev-tools) or set LINUXDEPLOY_QMAKE." >&2
        exit 1
    fi
fi

# linuxdeploy's bundled binutils can be too old to strip newer system libraries
# containing RELR relocations (e.g. `.relr.dyn`). Disabling stripping avoids
# build failures and only affects output size.
LINUXDEPLOY_NO_STRIP="${LINUXDEPLOY_NO_STRIP:-1}"
if [ "$LINUXDEPLOY_NO_STRIP" = "1" ]; then
    export NO_STRIP=1
    echo "linuxdeploy: stripping disabled (set LINUXDEPLOY_NO_STRIP=0 to enable)"
fi

./linuxdeploy-x86_64.AppImage \
    --appdir "$APPDIR" \
    --plugin qt \
    --output appimage \
    --desktop-file "$APPDIR/usr/share/applications/opentrack.desktop" \
    --icon-file "$ICON_FILE" \
    --executable "$APPDIR/usr/bin/opentrack"

# Rename
APPIMAGE_NAME="OpenTrack-NeuralNet-${VERSION}-x86_64.AppImage"

# If a previous run left the destination behind, remove it first.
rm -f -- "$APPIMAGE_NAME"

# Overwrite destination if needed and avoid failing if it already exists.
mv -f -- OpenTrack-*.AppImage "$APPIMAGE_NAME"

echo ""
echo "=== Build Complete ==="
echo "AppImage: $BUILD_DIR/$APPIMAGE_NAME"
echo ""
echo "To test:"
echo "  cd $BUILD_DIR"
echo "  ./$APPIMAGE_NAME"
echo ""
echo "To save to current directory:"
echo "  cp $BUILD_DIR/$APPIMAGE_NAME ."
echo ""
