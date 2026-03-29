#!/bin/bash

# Exit on any error
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Modern Music Player AppImage Build Process...${NC}"

# Find absolute paths based on script location
ASSET_DIR="$(ls)"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/../.." &> /dev/null && pwd )"
BUILD_DIR="$SCRIPT_DIR/build"

echo -e "${GREEN}Project Directory: ${PROJECT_DIR}${NC}"
echo -e "${GREEN}Build Directory: ${BUILD_DIR}${NC}"

# Ensure we have our isolated build directory configured
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 1. Clean previous AppDir
echo -e "${GREEN}[1/8] Cleaning previous AppDir...${NC}"
rm -rf AppDir
mkdir -p AppDir

# 2. Build and Install application to AppDir
echo -e "${GREEN}[2/8] Building and Installing application to AppDir...${NC}"
cmake "$PROJECT_DIR" -DCMAKE_INSTALL_PREFIX=/usr
cmake --build . -j$(nproc)
DESTDIR="$BUILD_DIR/AppDir" cmake --install .

# 3. Download LinuxDeploy dependencies if missing
echo -e "${GREEN}[3/8] Checking LinuxDeploy tools...${NC}"
for tool in linuxdeploy-x86_64.AppImage linuxdeploy-plugin-qt-x86_64.AppImage appimagetool-x86_64.AppImage; do
    if [[ ! -f "$tool" ]]; then
        echo "Downloading $tool..."
        if [[ "$tool" == "appimagetool-x86_64.AppImage" ]]; then
            wget -qnc "https://github.com/AppImage/AppImageKit/releases/download/continuous/$tool"
        elif [[ "$tool" == "linuxdeploy-x86_64.AppImage" ]]; then
            wget -qnc "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/$tool"
        else
            wget -qnc "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/$tool"
        fi
        chmod +x "$tool"
    fi
done

# 4. Create dummy SQL driver libraries (Fixes Arch/Manjaro plugin crawler crash)
echo -e "${GREEN}[4/8] Creating SQL dependency proxies...${NC}"
mkdir -p /tmp/fakelibs
echo "void dummy(){}" > /tmp/dummy.c
gcc -shared -o /tmp/fakelibs/libpq.so.5 /tmp/dummy.c
gcc -shared -o /tmp/fakelibs/libsybdb.so.5 /tmp/dummy.c
gcc -shared -o /tmp/fakelibs/libodbc.so.2 /tmp/dummy.c

# 5. Run linuxdeploy QT plugin handler
echo -e "${GREEN}[5/8] Running LinuxDeploy Qt Plugin execution...${NC}"
export QML_SOURCES_PATHS="$PROJECT_DIR/qml"
export EXTRA_QT_PLUGINS="iconengines;imageformats;wayland"
export NO_STRIP=1
export LD_LIBRARY_PATH=/tmp/fakelibs:$LD_LIBRARY_PATH

./linuxdeploy-x86_64.AppImage --appdir AppDir --plugin qt

# 6. Inject native Wayland proxy libraries
echo -e "${GREEN}[6/8] Injecting native Wayland Graphics and Shell plugins...${NC}"
cp -a /usr/lib/qt/plugins/wayland* AppDir/usr/plugins/ 2>/dev/null || true

# Run linuxdeploy again to finalize wayland shared library linking
./linuxdeploy-x86_64.AppImage --appdir AppDir

# 7. Clean intrusive host system glibc hooks
echo -e "${GREEN}[7/8] Purging GLib system bindings to prevent SIGABRT...${NC}"
rm -f AppDir/usr/lib/libglib* AppDir/usr/lib/libgobject* AppDir/usr/lib/libgmodule* AppDir/usr/lib/libgio* AppDir/usr/lib/libffi*

# 8. Squash AppDir into final AppImage
echo -e "${GREEN}[8/8] Packaging final AppImage...${NC}"
export ARCH=x86_64
export VERSION=1.0

# Remove old AppImage if exists
rm -f Modern_Music_Player-1.0-x86_64.AppImage Modern_Music_Player-x86_64.AppImage

./appimagetool-x86_64.AppImage AppDir Modern_Music_Player-x86_64.AppImage

echo -e "${GREEN}Build complete! Package output: $BUILD_DIR/Modern_Music_Player-x86_64.AppImage${NC}"
