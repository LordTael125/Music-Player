# Chapter 2 — The Build System (CMake)

## 2.1 What is a Build System?

When you write C++ code, it lives in `.h` and `.cpp` text files. These **cannot run directly**. A **build system** automates the steps:

```
Source Code (.cpp) → Compiler → Object Files (.o) → Linker → Executable
```

This project uses **CMake**, the industry-standard cross-platform build tool. CMake itself does not compile code — it generates the instructions (Makefiles or Ninja scripts) that tools like `g++` then use.

---

## 2.2 Full CMakeLists.txt with Line-by-Line Explanation

```cmake
cmake_minimum_required(VERSION 3.16)
```
> Declares the minimum CMake version required. 3.16 introduced `qt5_add_resources` improvements.

```cmake
project(MusicPlayer VERSION 1.0 LANGUAGES CXX)
```
> Declares the project name `MusicPlayer`, version `1.0`, and that only C++ code is used.

```cmake
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
```
> Forces C++ 17 features. We need C++17 for `std::function`, structured bindings, and lambdas with captures.

```cmake
set(CMAKE_INCLUDE_CURRENT_DIR ON)
```
> Tells the compiler to also look for headers in the current directory. Simplifies include paths.

```cmake
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
```
> These three lines are **Qt-specific magic**:
> - `AUTOMOC`: Automatically runs Qt's **Meta-Object Compiler** (moc) on any header that contains `Q_OBJECT`. This is what makes signals, slots, and properties work.
> - `AUTORCC`: Automatically packages `.qrc` resource files (QML scripts, icons) into the binary.
> - `AUTOUIC`: Auto-processes `.ui` files (we don't use these, but it's good practice to enable).

```cmake
find_package(Qt5 COMPONENTS Core Gui Widgets Qml Quick Sql Concurrent REQUIRED)
```
> Finds the Qt5 installation on your system and enables the specified **modules**:
>
> | Module | Purpose |
> |--------|---------|
> | `Core` | QString, QTimer, QObject, signals/slots |
> | `Gui` | QImage (for album art) |
> | `Widgets` | QApplication (needed for Qt Quick apps too) |
> | `Qml` | QQmlApplicationEngine, context properties |
> | `Quick` | QQuickImageProvider (for cover art) |
> | `Sql` | QSqlDatabase, QSqlQuery (SQLite) |
> | `Concurrent` | QtConcurrent::run() — background threads |

```cmake
find_package(PkgConfig REQUIRED)
pkg_check_modules(TAGLIB REQUIRED taglib)
```
> Finds **TagLib** using the system's `pkg-config` tool. This sets `TAGLIB_INCLUDE_DIRS` and `TAGLIB_LIBRARIES` variables for us.

```cmake
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/third_party
    ${TAGLIB_INCLUDE_DIRS}
)
```
> Tells the compiler where to find `.h` headers:
> - `include/` — our own headers
> - `third_party/` — where `miniaudio.h` lives
> - TagLib's system headers

```cmake
set(SOURCES
    src/main.cpp
    src/audio_engine.cpp
    include/audio_engine.h
    ...
)
```
> Lists every source file. **Note**: headers are listed here too. This is not strictly required for compilation, but it helps IDE tools (like Qt Creator) discover and show them.

```cmake
qt5_add_resources(RESOURCES qml.qrc icons.qrc)
```
> Packs our QML files and SVG icons **into the binary** so they travel with the executable. The files become accessible at runtime via `qrc:/` URLs.

```cmake
add_executable(MusicPlayer ${SOURCES} ${RESOURCES})
```
> Creates the final executable named `MusicPlayer`.

```cmake
target_link_libraries(MusicPlayer PRIVATE
    Qt5::Core Qt5::Gui Qt5::Widgets Qt5::Qml Qt5::Quick Qt5::Sql Qt5::Concurrent
    ${TAGLIB_LIBRARIES}
    dl pthread m
)
```
> Links the executable against:
> - All Qt5 modules
> - TagLib
> - `dl` (dynamic linker, needed by miniaudio for `dlopen`)
> - `pthread` (POSIX threads, needed by miniaudio)
> - `m` (math library, `libm`, for `sin`, `cos`, `fmaxf` in the equalizer)

---

## 2.3 The Qt Resource System (`.qrc` files)

Normal file paths like `"/home/user/qml/main.qml"` only work on that one machine. The `.qrc` resource system embeds files directly **inside the compiled binary**.

**qml.qrc** (simplified) looks like:
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

At runtime, you access these as:
```
qrc:/qml/main.qml
qrc:/qml/icons/play.svg
```

In `main.cpp` we load the root QML file like this:
```cpp
const QUrl url(QStringLiteral("qrc:/qml/main.qml"));
engine.load(url);
```

---

## 2.4 How to Build the Project

### On Linux (Ubuntu/Debian):

**Step 1: Install dependencies**
```bash
sudo apt install cmake build-essential qt5-default \
     libqt5qml5 libqt5sql5-sqlite qtconcurrent5 \
     libtaglib-dev pkg-config
```

**Step 2: Create a build directory (out-of-source build)**
```bash
cd "Music Player"
mkdir build && cd build
```
*Always build in a separate directory — keeps source clean.*

**Step 3: Configure with CMake**
```bash
cmake ..
```
CMake reads `CMakeLists.txt`, finds Qt5 and TagLib, and generates a `Makefile`.

**Step 4: Compile**
```bash
make -j$(nproc)
```
`-j$(nproc)` uses all CPU cores in parallel. This produces the `MusicPlayer` executable.

**Step 5: Run**
```bash
./MusicPlayer
```

---

## 2.5 What `AUTOMOC` Does — The Secret Behind Qt

This is crucial to understand. When you write:
```cpp
class AudioEngine : public QObject {
    Q_OBJECT           // <-- This macro
    Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY playingChanged)
    ...
signals:
    void playingChanged(bool isPlaying);
};
```

`Q_OBJECT` is a magic macro that tells CMake's `AUTOMOC` to run the **`moc` tool** on this header. `moc` (the Meta-Object Compiler) **generates extra C++ code** that enables:
- Signals and Slots connectivity
- Property system (read/write/notify)
- Runtime type information

The generated file is named something like `moc_audio_engine.cpp` and is automatically compiled alongside your code. You never write it — Qt generates it automatically.

---

## 2.6 Summary

```
Your Source Code
    ↓ moc (AUTOMOC)
Qt meta-object code generated
    ↓ rcc (AUTORCC)
.qrc files → embedded binary blobs
    ↓ g++ / clang++
Object files (.o)
    ↓ linker (ld)
MusicPlayer (final executable, ~20-40 MB)
```
