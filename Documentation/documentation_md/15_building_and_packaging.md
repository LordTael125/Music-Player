# Chapter 15 — Building, Running, and Packaging

## 15.1 Development Build (Linux)

### Prerequisites
```bash
sudo apt update
sudo apt install -y \
    cmake build-essential \
    qt5-default qtbase5-dev qtdeclarative5-dev \
    qml-module-qt-labs-platform \
    qml-module-qtquick-controls2 \
    qml-module-qtquick-layouts \
    libqt5sql5-sqlite libqt5concurrent5 \
    libtag1-dev libtagc0-dev \
    pkg-config
```

### Build Steps
```bash
# From the project root:
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Debug
make -j$(nproc)
./MusicPlayer
```

### Release Build (Optimized)
```bash
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

`Release` enables `-O2` optimization and disables debug symbols, producing a much faster binary.

---

## 15.2 Common Build Errors and Fixes

### Error: `Qt5 not found`
```
CMake Error: Could not find Qt5
```
**Fix**: Install Qt5 development packages.
```bash
sudo apt install qt5-default qtbase5-dev qtdeclarative5-dev
```

### Error: `taglib not found`
```
Package 'taglib' not found
```
**Fix**:
```bash
sudo apt install libtag1-dev pkg-config
```

### Error: `moc` failing / `Q_OBJECT` not recognized
Usually means CMake didn't enable `AUTOMOC`. Check `CMakeLists.txt` has:
```cmake
set(CMAKE_AUTOMOC ON)
```

### Error: `QSqlDatabase: QSQLITE driver not loaded`
```bash
sudo apt install libqt5sql5-sqlite
```

---

## 15.3 Project File Structure for IDE (Qt Creator)

Qt Creator can open the project directly from `CMakeLists.txt`:
1. Open Qt Creator → File → Open File or Project
2. Select `Music Player/CMakeLists.txt`
3. Qt Creator auto-detects the CMake project
4. Choose a Debug kit → Configure Project
5. Press Ctrl+R to build and run

Qt Creator provides:
- QML live preview (Qt Quick Designer)
- Integrated debugger with C++ and QML stacks
- Signal/slot visualizer

---

## 15.4 Creating a Linux AppImage

An AppImage bundles all Qt dependencies into a single portable file that runs on any Linux distro.

### What the build script does

The project includes `build_appimage.sh`:
```bash
#!/bin/bash
set -e

# Step 1: Build the release binary
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
make -j$(nproc)
make install DESTDIR=AppDir   # Install into AppDir/

# Step 2: Use linuxdeployqt to bundle Qt libraries
../linuxdeployqt-continuous-x86_64.AppImage \
    AppDir/usr/bin/MusicPlayer \
    -qmldir=../qml \             # Let it find QML imports to include
    -appimage \                   # Package as AppImage
    -no-translations
```

`linuxdeployqt`:
1. Finds which shared libraries `MusicPlayer` needs (`ldd MusicPlayer`)
2. Copies those `.so` files into the AppDir
3. Copies the necessary Qt plugins (SQL, Image, QML plugins)
4. Creates a launcher script
5. Packages everything into a self-contained `.AppImage` file

### Running the AppImage
```bash
chmod +x MusicPlayer-x86_64.AppImage
./MusicPlayer-x86_64.AppImage
```

---

## 15.5 Building on Windows with MSYS2

### Setup
1. Install [MSYS2](https://www.msys2.org/)
2. Open "MSYS2 MinGW 64-bit" shell
3. Install dependencies:
```bash
pacman -S mingw-w64-x86_64-qt5-base \
           mingw-w64-x86_64-qt5-declarative \
           mingw-w64-x86_64-qt5-quickcontrols2 \
           mingw-w64-x86_64-taglib \
           mingw-w64-x86_64-cmake \
           mingw-w64-x86_64-gcc
```

### Build
```bash
mkdir build && cd build
cmake .. -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release
mingw32-make -j4
```

### Deploying the Windows .exe
```bash
# windeployqt copies required Qt DLLs next to the .exe
windeployqt --qmldir ../qml MusicPlayer.exe
```

Copy the resulting folder (containing MusicPlayer.exe and DLLs) to a ZIP file for distribution.

---

## 15.6 The `.qrc` Resource System — How Files Get Into the Binary

Two resource files pack content into the binary:

**qml.qrc**:
```xml
<RCC>
  <qresource prefix="/qml">
    <file>qml/main.qml</file>
    <file>qml/LibraryView.qml</file>
    <file>qml/EqualizerView.qml</file>
    <file>qml/NowPlayingView.qml</file>
  </qresource>
</RCC>
```

**icons.qrc**:
```xml
<RCC>
  <qresource prefix="/qml/icons">
    <file>qml/icons/play.svg</file>
    <file>qml/icons/pause.svg</file>
    <file>qml/icons/next.svg</file>
    <file>qml/icons/prev.svg</file>
    <file>qml/icons/volume.svg</file>
    <file>qml/icons/eq.svg</file>
    <!-- ...all other icons... -->
  </qresource>
</RCC>
```

The `qt5_add_resources(RESOURCES qml.qrc icons.qrc)` CMake call runs `rcc` to embed these files. At runtime, they're accessed as:
- `qrc:/qml/main.qml` — by the engine.load() call
- `qrc:/qml/icons/play.svg` — by QML Image sources

---

## 15.7 Runtime Data Storage

The app stores data in the platform's standard application data directory:

| Platform | Path |
|---------|------|
| Linux | `~/.local/share/MusicPlayer/tracks.db` |
| Windows | `C:\Users\<user>\AppData\Roaming\MusicPlayer\tracks.db` |

EQ presets (QSettings):
| Platform | Path |
|---------|------|
| Linux | `~/.config/ModernMusicPlayer/EqualizerPresets.ini` |
| Windows | Windows Registry: `HKCU\Software\ModernMusicPlayer\EqualizerPresets` |

---

## 15.8 Quick Reference: Key Files

| File | Role |
|------|------|
| `CMakeLists.txt` | Build configuration |
| `src/main.cpp` | App entry point, wires all components |
| `include/track.h` | Plain data struct for one song |
| `include/track_model.h` | Qt model exposing tracks to QML |
| `include/library_scanner.h` | Scans folders, reads tags, writes DB |
| `include/audio_engine.h` | Plays audio, volume, seek, EQ chain |
| `include/equalizer.h` | 10-band EQ with presets |
| `include/cover_art_provider.h` | Serves album art images to QML |
| `src/track_model.cpp` | Model implementation + sorting/filtering |
| `src/library_scanner.cpp` | TagLib + SQLite + QtConcurrent |
| `src/audio_engine.cpp` | miniaudio integration |
| `src/equalizer.cpp` | EQ band management + QSettings presets |
| `src/cover_art_provider.cpp` | TagLib image extraction → QImage |
| `qml/main.qml` | Root window, playback bar, popups, shortcuts |
| `qml/LibraryView.qml` | Sidebar + tabbed tile grid + StackView |
| `qml/EqualizerView.qml` | 10-band EQ sliders + preset ComboBox |
| `qml/NowPlayingView.qml` | Full-screen now playing overlay |
| `third_party/miniaudio.h` | Complete audio engine (single header) |
| `build_appimage.sh` | Linux AppImage packaging script |

---

## 15.9 Summary: The Mental Model

When everything is running:

```
                     ┌─────────────────────────┐
                     │      QML Frontend        │
                     │   (main.qml,             │
                     │    LibraryView.qml,       │
                     │    EqualizerView.qml)     │
                     │                          │
                     │  Reads: audioEngine.*     │
                     │  Reads: trackModel.*      │
                     │  Calls: audioEngine.play()│
                     │  Calls: trackModel.filter │
                     └──────────┬──┬────────────┘
                                │  │  (context properties + signals)
          ┌─────────────────────┘  └──────────────┐
          │                                       │
┌─────────▼──────────┐               ┌────────────▼──────────┐
│    AudioEngine     │               │      TrackModel        │
│  miniaudio engine  │               │  QAbstractListModel    │
│  EQ node graph     ◄───signal──────┤  m_allTracks[]         │
│  QTimer heartbeat  │               │  m_displayIndices[]    │
│  Equalizer child   │               └────────────▲──────────┘
└─────────┬──────────┘                            │
          │ sound output                           │ tracksAdded signal
          ▼                                        │
    Audio Device                        ┌──────────┴──────────┐
    (PulseAudio/                        │   LibraryScanner    │
     WASAPI/CoreAudio)                  │  QtConcurrent thread│
                                        │  TagLib tag reading │
                               ┌────────►  SQLite database    │
                               │        └─────────────────────┘
                               │
                         CoverArtProvider
                         (image://musiccover/)
                         TagLib image extraction
```

Every arrow is either a Qt signal/slot connection, a Q_PROPERTY binding, or a direct method call — nothing is global state, nothing is shared memory without synchronization.

Congratulations — you now understand the complete architecture of this music player from the CMake build system all the way to the QML pixels on screen!
