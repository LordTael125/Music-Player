# Modern Music Player — Complete Project Handbook

Welcome to the complete, from-scratch developer handbook for the **Modern Music Player**.

This handbook is written for someone who knows basic C++ and wants to fully understand every piece of this application — from the build system, through the C++ backend, all the way to the QML frontend.

## Table of Contents

| Chapter | File | Topic |
|---------|------|-------|
| 1 | [01_introduction.md](01_introduction.md) | Project Overview, Goals, Technology Stack |
| 2 | [02_build_system.md](02_build_system.md) | CMake, Qt5, Linking Libraries, Building the App |
| 3 | [03_cpp_foundations.md](03_cpp_foundations.md) | Qt Basics: QObject, Signals & Slots, Q_PROPERTY |
| 4 | [04_data_layer.md](04_data_layer.md) | Track struct, TrackModel, QAbstractListModel |
| 5 | [05_library_scanner.md](05_library_scanner.md) | LibraryScanner, TagLib, SQLite, QtConcurrent |
| 6 | [06_audio_engine.md](06_audio_engine.md) | AudioEngine, miniaudio, Node Graph, EQ Chain |
| 7 | [07_equalizer.md](07_equalizer.md) | Equalizer class, Presets, QSettings |
| 8 | [08_cover_art.md](08_cover_art.md) | CoverArtProvider, QQuickImageProvider |
| 9 | [09_main_bridge.md](09_main_bridge.md) | main.cpp, Wiring Backend to QML, Context Properties |
| 10 | [10_qml_fundamentals.md](10_qml_fundamentals.md) | QML Language Crash Course for C++ Devs |
| 11 | [11_qml_main_window.md](11_qml_main_window.md) | main.qml deep-dive: Window, Layouts, Playback Bar |
| 12 | [12_qml_library_view.md](12_qml_library_view.md) | LibraryView.qml: Tabs, Tiles, Filtering |
| 13 | [13_qml_equalizer_view.md](13_qml_equalizer_view.md) | EqualizerView.qml, NowPlayingView.qml |
| 14 | [14_dataflow.md](14_dataflow.md) | Full End-to-End Dataflow Diagrams |
| 15 | [15_building_and_packaging.md](15_building_and_packaging.md) | Build Steps, AppImage, Deploy on Windows |

> **Tip:** Read the chapters in order on your first pass. Each chapter builds on the previous.
<div class="page-break"></div>
# Chapter 1 — Introduction & Technology Stack

## 1.1 What is this project?

**Modern Music Player** is a cross-platform, local-library music player built entirely in **C++ with a Qt 5 / QML frontend**. It can:

- Scan a folder (and all sub-folders) for audio files
- Read metadata (artist, album, title, track number, genre) from audio tags
- Display artwork embedded in audio files
- Play music using a high-performance audio engine
- Adjust sound using a 10-band graphic equalizer
- Maintain a playback queue with skip, repeat, seek functionality

The project is structured so that the **business logic lives in C++** and the **UI is written in QML** (Qt's declarative UI language). These two worlds communicate through Qt's signal-slot mechanism and context properties.

---

## 1.2 Technology Stack at a Glance

| Technology | Role | Why |
|---|---|---|
| **C++ 17** | Core language | Performance, type safety, rich ecosystem |
| **Qt 5** | Framework glue (widgets, threading, SQL, networking) | Comprehensive cross-platform framework |
| **QML / Qt Quick 2** | Declarative UI language | Fast, smooth, modern UI without Qt Widgets verbosity |
| **miniaudio** (header-only) | Audio playback engine | Tiny, zero-dependency, powerful node graph |
| **TagLib** | Audio tag reading (ID3, Vorbis, MP4) | Mature, reliable library for music metadata |
| **SQLite via Qt Sql** | Persistent library database | Lightweight embedded database, ships with Qt |
| **QtConcurrent** | Background threading | Safe Qt-aware thread pool |
| **CMake 3.16+** | Build system | Industry standard, cross-platform build tool |

---

## 1.3 How This App Is Different From a "Hello World" Qt App

Most Qt tutorials show:
```cpp
QLabel *label = new QLabel("Hello");
label->show();
```

This app is a full production-grade application with:
- **Separations of concern**: Each class has exactly one job
- **Asynchronous operations**: File scanning happens on a background thread
- **Custom Qt Model**: `TrackModel` extends `QAbstractListModel` so QML can bind to it natively
- **Node-graph audio pipeline**: Sound → EQ Band 1 → EQ Band 2 → … → Speaker
- **Custom image provider**: Album art is fetched on-demand by URL through `CoverArtProvider`

---

## 1.4 Directory Layout

```
Music Player/
├── CMakeLists.txt          ← Build script
├── include/                ← All .h header files
│   ├── track.h             ← Plain data struct: a single song's info
│   ├── track_model.h       ← Qt model bridging Track data to QML
│   ├── library_scanner.h   ← Scans folders, reads tags, writes to DB
│   ├── audio_engine.h      ← Plays audio, controls volume/seek
│   ├── equalizer.h         ← 10-band EQ with presets
│   └── cover_art_provider.h← Converts file paths to QImages for QML
├── src/                    ← All .cpp implementation files
│   ├── main.cpp            ← App entry point, wires everything together
│   ├── track_model.cpp
│   ├── library_scanner.cpp
│   ├── audio_engine.cpp
│   ├── equalizer.cpp
│   └── cover_art_provider.cpp
├── qml/                    ← All QML (UI) files
│   ├── main.qml            ← Root window, playback bar, popups, shortcuts
│   ├── LibraryView.qml     ← The main tabbed library browser
│   ├── EqualizerView.qml   ← The EQ knobs UI
│   ├── NowPlayingView.qml  ← Full-screen now playing overlay
│   └── icons/              ← SVG icons used in the UI
├── third_party/            ← Bundled header-only libraries
│   └── miniaudio.h         ← The entire audio engine in one file
├── qml.qrc                 ← Qt resource file listing QML files
└── icons.qrc               ← Qt resource file listing icon SVGs
```

---

## 1.5 The "Two Worlds" Mental Model

The most important concept in this project is understanding how C++ talks to QML.

```
┌─────────────────────────────────────────┐
│                 C++ World               │
│                                         │
│   AudioEngine   LibraryScanner          │
│   TrackModel    Equalizer               │
│   CoverArtProvider                      │
│                                         │
│   These live in memory as QObject       │
│   subclasses.                           │
└───────────────┬─────────────────────────┘
                │  exposed via
                │  setContextProperty()
                │  and signals/slots
┌───────────────▼─────────────────────────┐
│                QML World                │
│                                         │
│   main.qml    LibraryView.qml           │
│   EqualizerView.qml                     │
│                                         │
│   These access C++ objects like         │
│   JavaScript objects using the names    │
│   given in setContextProperty.          │
└─────────────────────────────────────────┘
```

When QML calls:
```qml
audioEngine.play()
```

It is actually calling the `AudioEngine::play()` C++ slot through Qt's meta-object system. This magic is covered in detail in Chapter 9.

---

## 1.6 Prerequisites

Before reading this handbook, you should know:
- Basic C++ (classes, methods, pointers, `#include`)
- What a `.h` (header) vs `.cpp` (source) file is

You do NOT need to know:
- Qt (we teach it from scratch)
- QML (we teach it from scratch)
- Audio programming (we explain every concept)

Let's begin!
<div class="page-break"></div>
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
<div class="page-break"></div>
# Chapter 3 — Qt C++ Foundations

Before reading the individual class chapters, you must understand the four pillars of Qt programming that this project relies on heavily.

---

## 3.1 Pillar 1: QObject — The Base of Everything

Every meaningful class in this project inherits from `QObject`. This is not optional — `QObject` is what gives a class access to signals, slots, and properties.

```cpp
// A minimal QObject subclass
#include <QObject>

class MyClass : public QObject {
    Q_OBJECT   // MANDATORY macro — must be the first line inside the class
public:
    explicit MyClass(QObject *parent = nullptr);  // parent pointer: memory management
};
```

### The Parent-Child Memory Model
Qt uses a **parent-child ownership tree**. When a parent `QObject` is destroyed, it automatically destroys all its children:

```cpp
AudioEngine audioEngine;                    // parent = nullptr (stack-allocated)
Equalizer *eq = new Equalizer(&audioEngine); // eq's parent = &audioEngine
// When audioEngine is destroyed, eq is automatically deleted too
```

This means you rarely call `delete` manually in Qt code. **Always pass a parent** when heap-allocating a `QObject`.

---

## 3.2 Pillar 2: Signals and Slots

This is Qt's event system. It lets completely unrelated objects communicate **without knowing about each other directly**.

### Declaring Signals
```cpp
class AudioEngine : public QObject {
    Q_OBJECT
signals:
    void playingChanged(bool isPlaying);   // "something happened"
    void positionChanged(float position);   // "my state changed"
    void playbackFinished();               // "event occurred"
};
```
Signals are **declared** but **never defined** — Qt's `moc` tool generates the implementation automatically.

### Declaring Slots
```cpp
class TrackModel : public QAbstractListModel {
    Q_OBJECT
public slots:
    void setTracks(const QVector<Track> &tracks);   // can be connected to a signal
    void filterByArtist(const QString &artist);
};
```

### Connecting Them
```cpp
// In main.cpp:
QObject::connect(&libraryScanner, &LibraryScanner::tracksAdded,
                 &trackModel,     &TrackModel::setTracks);
```

Now whenever `libraryScanner` emits `tracksAdded(someVector)`, Qt automatically calls `trackModel.setTracks(someVector)`. The two objects don't know each other — they are loosely coupled.

### Emitting a Signal
```cpp
void AudioEngine::play() {
    ma_sound_start(&m_sound);
    emit playingChanged(true);  // "emit" keyword triggers all connected slots
}
```

### Thread Safety
Qt signals and slots are thread-safe when the objects involved live on different threads. Qt automatically queues the call across thread boundaries using `Qt::QueuedConnection`. This is used in `LibraryScanner` — scanning happens on a background thread, but `tracksAdded` is safely delivered to the main thread.

---

## 3.3 Pillar 3: Q_PROPERTY — The Bridge to QML

`Q_PROPERTY` is what makes a C++ class member accessible from QML as if it were a JavaScript property.

```cpp
class AudioEngine : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool  isPlaying READ isPlaying          NOTIFY playingChanged)
    Q_PROPERTY(float position  READ position  WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(float volume    READ volume    WRITE setVolume    NOTIFY volumeChanged)
    Q_PROPERTY(float duration  READ duration            NOTIFY durationChanged)
    Q_PROPERTY(Equalizer* equalizer READ equalizer CONSTANT)
```

Each `Q_PROPERTY` declares:
- **Type** — `bool`, `float`, pointer, etc.
- **Name** — the name visible in QML (e.g., `audioEngine.isPlaying`)
- **READ** — which C++ getter to call
- **WRITE** *(optional)* — which C++ setter to call (makes it writable from QML)
- **NOTIFY** — which signal fires when the value changes (enables QML data binding)
- **CONSTANT** *(optional)* — no setter, no notify needed (value never changes)

In QML you can then write:
```qml
// Binding: this text updates automatically whenever positionChanged fires
Text { text: audioEngine.position.toFixed(1) + " sec" }

// Write through the WRITE setter
Slider { onMoved: audioEngine.position = value }

// Read a CONSTANT property
audioEngine.equalizer.bandGain(0)
```

---

## 3.4 Pillar 4: Q_INVOKABLE — Calling C++ Functions from QML

`Q_PROPERTY` lets QML read/write values. But sometimes QML needs to **call a function**:

```cpp
class Equalizer : public QObject {
    Q_OBJECT
public:
    Q_INVOKABLE int          bandCount() const;
    Q_INVOKABLE float        bandGain(int index) const;
    Q_INVOKABLE float        bandFrequency(int index) const;
    Q_INVOKABLE QStringList  getPresetNames() const;
    Q_INVOKABLE void         loadPreset(const QString &name);
    Q_INVOKABLE void         saveCustomPreset(const QString &name);
    Q_INVOKABLE void         deleteCustomPreset(const QString &name);
    Q_INVOKABLE bool         isCustomPreset(const QString &name) const;
};
```

Adding `Q_INVOKABLE` before a method makes it callable from QML:
```qml
// In EqualizerView.qml:
var freq = audioEngine.equalizer.bandFrequency(0)   // calls C++ directly
audioEngine.equalizer.loadPreset("Rock")
```

Public slots can also be called from QML without `Q_INVOKABLE`. `Q_INVOKABLE` is preferred for const functions or ones that don't need slot semantics.

---

## 3.5 QString — Qt's String Class

Qt programs almost never use `std::string`. They use `QString`:

```cpp
QString name = "Unknown Artist";
QString path = filePath.toUtf8();   // convert to UTF-8 QByteArray

// Concatenation
QString display = track.title + " - " + track.artist;

// Check contents
if (track.title.isEmpty()) { ... }
if (filePath.endsWith(".mp3", Qt::CaseInsensitive)) { ... }
if (filePath.startsWith("file://")) { ... }

// Convert between Qt and standard types
std::string std_str = qtString.toStdString();
QString fromStd = QString::fromStdString(std_str);
QString fromWide = QString::fromStdWString(wideStr);  // used for TagLib
```

---

## 3.6 QVector — Qt's Dynamic Array

Like `std::vector` but Qt-flavored:

```cpp
QVector<Track> m_allTracks;    // holds Track structs
QVector<int>   m_displayIndices; // integer indices into m_allTracks

m_allTracks.append(newTrack);
m_allTracks.size();            // number of elements
m_allTracks[i];                // element access (same as std::vector)
m_allTracks.clear();           // remove all

// Range-based for loop
for (const Track &t : qAsConst(m_allTracks)) {
    // qAsConst prevents detach (copy-on-write optimization)
}
```

---

## 3.7 Lambda Functions in Qt

Modern Qt (C++11 and above) uses lambdas extensively for one-off callbacks:

```cpp
// Timer callback
connect(&m_progressTimer, &QTimer::timeout, this, [this]() {
    if (m_soundLoaded && isPlaying()) {
        emit positionChanged(position());  // update QML every 250ms
    }
});

// QtConcurrent background task
QtConcurrent::run([this, path]() {
    // This runs on a background thread
    // "this" and "path" are captured by value/reference
    QDirIterator it(path, ...);
    ...
});
```

`[this, path]` is the **capture list** — variables from the outer scope that the lambda can use:
- `[this]` — capture the object pointer so you can call `emit`, access members
- `[=]` — capture everything by value (copy)
- `[&]` — capture everything by reference (dangerous if the lambda outlives the scope)
<div class="page-break"></div>
# Chapter 4 — The Data Layer: Track, TrackModel, QAbstractListModel

## 4.1 The `Track` Struct — The Atom of the Music Library

Everything in this app revolves around one simple plain-data struct:

```cpp
// include/track.h
#ifndef TRACK_H
#define TRACK_H

#include <QString>

struct Track {
    QString filePath;       // Absolute path: "/home/user/music/song.mp3"
    QString title;          // "Bohemian Rhapsody"
    QString artist;         // "Queen"
    QString album;          // "A Night at the Opera"
    QString genre;          // "Rock"
    int duration{0};        // Duration in seconds (e.g., 354)
    bool hasCoverArt{false};// Does the file have an embedded album image?
    int trackNumber{0};     // Track # on disc (1, 2, 3...)
    int discNumber{0};      // Disc number for multi-disc albums
};

#endif // TRACK_H
```

This is a **plain struct** — no QObject, no signals, no methods. It is a pure data container. The `{0}` and `{false}` are **in-class member initializers** (C++11), meaning the values default to zero/false if not set.

`QVector<Track>` is then the fundamental collection: the entire music library is a vector of these structs.

---

## 4.2 Why We Need a Custom Qt Model

QML's `ListView` and `Repeater` need data to come from a **Qt Model**. You can't just hand QML a raw `QVector<Track>` — it wouldn't know how to read from it.

Qt provides `QAbstractListModel` as the base class for list data models. You subclass it and override three methods, and QML can automatically bind to it.

---

## 4.3 TrackModel — The Full Class

### Header: `include/track_model.h`

```cpp
#include "track.h"
#include <QAbstractListModel>
#include <QVector>

class TrackModel : public QAbstractListModel {
    Q_OBJECT

public:
    // Step 1: Define "roles" — these are like column names in a table
    enum TrackRoles {
        TitleRole    = Qt::UserRole + 1,  // Qt::UserRole = 256, so TitleRole = 257
        ArtistRole,                        // 258
        AlbumRole,                         // 259
        GenreRole,                         // 260
        DurationRole,                      // 261
        FilePathRole,                      // 262
        HasCoverArtRole                    // 263
    };

    explicit TrackModel(QObject *parent = nullptr);

    // Step 2: Override the three mandatory virtual methods
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Step 3: Add useful extras
    Q_INVOKABLE QVariantMap get(int row) const;   // Get a whole row as a JS object
    void setTracks(const QVector<Track> &tracks); // Replace all tracks
    void addTracks(const QVector<Track> &tracks); // Append tracks

public slots:
    void filterAll();
    void filterByArtist(const QString &artist);
    void filterByAlbum(const QString &album);
    void filterByFolder(const QString &folder);
    void filterByCollection(const QString &collection);

    Q_INVOKABLE QVariantList getArtistTiles() const;
    Q_INVOKABLE QVariantList getAlbumTiles() const;
    Q_INVOKABLE QVariantList getFolderTiles() const;
    Q_INVOKABLE QVariantList getCollectionTiles() const;

private:
    QString getCommonRootPath() const;
    void updateDisplayIndices(std::function<bool(const Track &)> predicate);

    QVector<Track> m_allTracks;        // ALL tracks ever loaded
    QVector<int>   m_displayIndices;   // INDICES of tracks currently shown
};
```

### The Two-Array Design Explained

The key architectural decision is the separation of `m_allTracks` and `m_displayIndices`:

```
m_allTracks:       [ Track0, Track1, Track2, Track3, Track4 ]
                      idx=0   idx=1   idx=2   idx=3   idx=4

filterByArtist("Queen"):
m_displayIndices:  [ 1, 3 ]    ← only tracks at index 1 and 3 are "Queen"

QML sees a list of 2 items:
  - Row 0 → m_allTracks[1]
  - Row 1 → m_allTracks[3]
```

This design means **filtering is free** — we never copy or delete tracks, just change which indices are visible. The full library is always in memory.

---

## 4.4 Implementing the Three Mandatory Methods

### `rowCount` — How Many Rows?

```cpp
int TrackModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid())   // For a list (not tree), parent is always invalid
        return 0;
    return m_displayIndices.count();  // Only show filtered items
}
```

### `data` — What Is In Row N?

```cpp
QVariant TrackModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_displayIndices.count())
        return QVariant();  // Invalid row → return empty

    // Translate display index → actual track index
    int actualIndex = m_displayIndices[index.row()];
    const Track &track = m_allTracks[actualIndex];

    switch (role) {
    case TitleRole:      return track.title;
    case ArtistRole:     return track.artist;
    case AlbumRole:      return track.album;
    case GenreRole:      return track.genre;
    case DurationRole:   return track.duration;
    case FilePathRole:   return track.filePath;
    case HasCoverArtRole: return track.hasCoverArt;
    }

    return QVariant();
}
```

`QVariant` is Qt's universal value type — it can hold a string, int, bool, list, or map. QML knows how to automatically unpack them.

### `roleNames` — The Mapping from ID to Name

```cpp
QHash<int, QByteArray> TrackModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[TitleRole]      = "title";
    roles[ArtistRole]     = "artist";
    roles[AlbumRole]      = "album";
    roles[GenreRole]      = "genre";
    roles[DurationRole]   = "duration";
    roles[FilePathRole]   = "filePath";
    roles[HasCoverArtRole] = "hasCoverArt";
    return roles;
}
```

This mapping is the bridge to QML. After this, in QML you can write:
```qml
ListView {
    model: trackModel    // the C++ TrackModel exposed via context property
    delegate: Text {
        text: title + " - " + artist   // "title" maps to TitleRole automatically
    }
}
```

---

## 4.5 Filtering — How It Works

```cpp
// Generic helper: takes a function that returns true/false for each track
void TrackModel::updateDisplayIndices(std::function<bool(const Track &)> predicate) {
    beginResetModel();           // Tell QML: "about to change everything"
    m_displayIndices.clear();
    for (int i = 0; i < m_allTracks.size(); ++i) {
        if (predicate(m_allTracks[i])) {
            m_displayIndices.append(i);
        }
    }
    endResetModel();             // Tell QML: "done, re-read everything"
}

// Show all tracks
void TrackModel::filterAll() {
    updateDisplayIndices([](const Track &) { return true; });
}

// Show only tracks by a specific artist
void TrackModel::filterByArtist(const QString &artist) {
    updateDisplayIndices([artist](const Track &t) { return t.artist == artist; });
}
```

`beginResetModel()` / `endResetModel()` are critical — they tell any attached QML `ListView` to stop reading data, wait for the update, then refresh itself. Without these, the UI would show stale or corrupt data.

---

## 4.6 The `get()` Method — Exporting a Full Row to QML

```cpp
QVariantMap TrackModel::get(int row) const {
    QVariantMap map;
    QModelIndex idx = index(row, 0);
    if (!idx.isValid()) return map;

    QHash<int, QByteArray> roles = roleNames();
    for (auto it = roles.begin(); it != roles.end(); ++it) {
        map.insert(QString::fromUtf8(it.value()), data(idx, it.key()));
    }
    return map;
}
```

This converts a row into a `QVariantMap`, which QML sees as a JavaScript object:
```qml
// In main.qml, building the playback queue:
for (var i = 0; i < trackModel.rowCount(); i++) {
    newQueue.push(trackModel.get(i));  // push JS objects into queue array
}
// Then access: queue[0].title, queue[0].filePath, queue[0].hasCoverArt
```

---

## 4.7 Sorting Logic in `setTracks`

When tracks are first loaded, they are sorted:

```cpp
std::sort(m_allTracks.begin(), m_allTracks.end(),
          [](const Track &a, const Track &b) {
              if (a.artist == b.artist) {
                  if (a.album == b.album) {
                      if (a.discNumber != b.discNumber)
                          return a.discNumber < b.discNumber;
                      if (a.trackNumber != b.trackNumber)
                          return a.trackNumber < b.trackNumber;
                      return a.title < b.title;
                  }
                  return a.album < b.album;
              }
              return a.artist < b.artist;
          });
```

Priority: **Artist → Album → Disc → Track Number → Title**. This ensures albums appear in the natural CD track order.

---

## 4.8 Tile Queries — Getting Unique Artists/Albums

The UI shows "Artist Tiles" (one tile per unique artist). `getArtistTiles()` produces this:

```cpp
QVariantList TrackModel::getArtistTiles() const {
    QVariantList list;
    QSet<QString> seenArtists;          // Set ensures uniqueness
    for (const auto &t : qAsConst(m_allTracks)) {
        if (t.artist.isEmpty() || seenArtists.contains(t.artist))
            continue;
        seenArtists.insert(t.artist);
        QVariantMap map;
        map["name"]       = t.artist;
        map["hasCoverArt"] = t.hasCoverArt;
        map["filePath"]   = t.filePath;  // Use this track's art to represent the artist
        list.append(map);
    }
    return list;
}
```

QML receives a JavaScript array of objects: `[ {name: "Queen", hasCoverArt: true, filePath: "..."}, ... ]`.
<div class="page-break"></div>
# Chapter 5 — LibraryScanner: Tags, Database, and Background Threads

## 5.1 What LibraryScanner Does

`LibraryScanner` is the engine that:
1. Walks a directory tree looking for audio files (`.mp3`, `.flac`, `.wav`, `.m4a`, `.aac`, `.ogg`)
2. Reads metadata (tags) from each file using **TagLib**
3. Checks if each file has embedded cover art
4. Saves everything to an **SQLite database** for persistence
5. Emits signals so the rest of the app knows the library has changed

It does all of this **on a background thread** using `QtConcurrent::run` so the UI never freezes.

---

## 5.2 TagLib — Reading Music Metadata

A music file like an `.mp3` contains two things:
- The **audio data** (the actual sound, compressed with MP3/AAC/FLAC codec)
- **Tags** (metadata): artist, title, album, genre, track number, cover art, etc.

**TagLib** is a C++ library that can read (and write) these tags across all formats.

### Basic TagLib Usage
```cpp
#include <taglib/fileref.h>
#include <taglib/tag.h>

TagLib::FileRef f("/path/to/song.mp3");

if (!f.isNull() && f.tag()) {
    TagLib::Tag *tag = f.tag();
    QString title  = QString::fromStdWString(tag->title().toWString());
    QString artist = QString::fromStdWString(tag->artist().toWString());
    QString album  = QString::fromStdWString(tag->album().toWString());
    QString genre  = QString::fromStdWString(tag->genre().toWString());
}

if (f.audioProperties()) {
    int durationSeconds = f.audioProperties()->lengthInSeconds();
}
```

`TagLib::String` uses a wide-character encoding internally. We convert through `toWString()` then `QString::fromStdWString()` to safely handle Unicode characters (é, ü, 中文, etc.).

### Reading Track/Disc Numbers via PropertyMap

The simple `tag->track()` method may not always work for all formats. The `PropertyMap` is more reliable:

```cpp
TagLib::PropertyMap properties = f.file()->properties();

if (properties.contains("TRACKNUMBER") && !properties["TRACKNUMBER"].isEmpty()) {
    track.trackNumber = properties["TRACKNUMBER"].front().toInt();
} else {
    track.trackNumber = tag->track();  // fallback
}

if (properties.contains("DISCNUMBER") && !properties["DISCNUMBER"].isEmpty()) {
    track.discNumber = properties["DISCNUMBER"].front().toInt();
}
```

### Checking for Cover Art (Format-Specific)

Cover art detection requires format-specific TagLib classes:

```cpp
// MP3: looks for APIC (Attached Picture) ID3v2 frame
if (filePath.endsWith(".mp3", Qt::CaseInsensitive)) {
    TagLib::MPEG::File mpegFile(filePath.toUtf8().constData());
    if (mpegFile.hasID3v2Tag()) {
        auto frameList = mpegFile.ID3v2Tag()->frameListMap()["APIC"];
        if (!frameList.isEmpty()) hasArt = true;
    }
}
// FLAC: has its own picture list
else if (filePath.endsWith(".flac", Qt::CaseInsensitive)) {
    TagLib::FLAC::File flacFile(filePath.toUtf8().constData());
    if (flacFile.isValid() && !flacFile.pictureList().isEmpty()) hasArt = true;
}
// M4A/AAC: uses "covr" item in the MP4 tag
else if (filePath.endsWith(".m4a", Qt::CaseInsensitive)) {
    TagLib::MP4::File mp4File(filePath.toUtf8().constData());
    if (mp4File.isValid() && mp4File.tag()) {
        if (mp4File.tag()->itemMap().contains("covr")) hasArt = true;
    }
}
```

---

## 5.3 SQLite via Qt Sql — The Persistent Library Database

Without a database, every time you launch the app it would have to re-scan all your music. The database lets us remember what we already scanned.

### Database Initialization

```cpp
void LibraryScanner::initializeDatabase() {
    // Find a writable location on this platform (Linux: ~/.local/share/AppName/)
    QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dataDir);   // Create the directory if it doesn't exist

    QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE");   // Use SQLite driver
    db.setDatabaseName(dataDir + "/tracks.db");               // File path for the .db file

    if (db.open()) {
        QSqlQuery query;
        // CREATE TABLE IF NOT EXISTS means this is safe to run on every launch
        query.exec(
            "CREATE TABLE IF NOT EXISTS tracks ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT, "
            "title TEXT, artist TEXT, album TEXT, genre TEXT, "
            "duration INTEGER, filePath TEXT UNIQUE, "   // UNIQUE prevents duplicate paths
            "hasCoverArt INTEGER, trackNumber INTEGER, discNumber INTEGER)"
        );
        // Migration patches — safe to run even if column already exists
        query.exec("ALTER TABLE tracks ADD COLUMN trackNumber INTEGER DEFAULT 0");
        query.exec("ALTER TABLE tracks ADD COLUMN discNumber INTEGER DEFAULT 0");
    }
}
```

`QStandardPaths::AppDataLocation` returns the correct platform path:
- Linux: `~/.local/share/MusicPlayer/`
- Windows: `C:\Users\<user>\AppData\Roaming\MusicPlayer\`

### Loading the Database on Startup

```cpp
void LibraryScanner::loadDatabase() {
    QVector<Track> loadedTracks;
    QSqlQuery query("SELECT title, artist, album, genre, duration, filePath, "
                    "hasCoverArt, trackNumber, discNumber FROM tracks");

    while (query.next()) {          // Iterate over rows
        Track t;
        t.title      = query.value(0).toString();
        t.artist     = query.value(1).toString();
        // ... etc
        loadedTracks.append(t);
    }

    if (!loadedTracks.isEmpty()) {
        // QTimer::singleShot(0, ...) defers the emit to the next event loop iteration
        // Needed because this may be called from the constructor, before anyone
        // has connected to the signal yet
        QTimer::singleShot(0, this, [this, loadedTracks]() {
            emit tracksAdded(loadedTracks);
        });
    }
}
```

### Inserting Scanned Tracks with a Transaction

```cpp
db.transaction();     // Begin a batch — much faster than individual INSERTs
QSqlQuery insertQuery(db);
insertQuery.prepare(
    "INSERT OR REPLACE INTO tracks "
    "(title, artist, album, genre, duration, filePath, hasCoverArt, trackNumber, discNumber) "
    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
);

for (const Track &t : newTracks) {
    insertQuery.bindValue(0, t.title);
    insertQuery.bindValue(1, t.artist);
    // ...
    insertQuery.bindValue(5, t.filePath);
    insertQuery.exec();
}
db.commit();   // Commit all at once — 10x - 100x faster than commit per row
```

`INSERT OR REPLACE` means: if a row with this `filePath` already exists (UNIQUE constraint), replace it. This makes re-scanning idempotent.

---

## 5.4 Background Threading with QtConcurrent

File scanning can take seconds for a large library. Blocking the main (UI) thread would freeze the window. `QtConcurrent::run` sends the work to a thread pool:

```cpp
void LibraryScanner::scanDirectory(const QString &directoryPath) {
    emit scanStarted();   // Tell the UI to show a progress spinner

    QtConcurrent::run([this, path]() {
        // ⚠️ This lambda runs on a BACKGROUND THREAD
        // Do NOT call Qt UI functions here
        // Do NOT emit signals directly to QML-bound slots across threads (safe here because Qt queues them)

        QDirIterator it(path,
                        QStringList() << "*.mp3" << "*.flac" << "*.wav" << "*.m4a" << "*.aac" << "*.ogg",
                        QDir::Files, QDirIterator::Subdirectories);  // Recursive!

        int filesProcessed = 0;
        QVector<Track> newTracks;

        while (it.hasNext()) {
            QString filePath = it.next();
            // ... read tags, detect art ...
            newTracks.append(track);
            filesProcessed++;

            if (filesProcessed % 10 == 0) {
                emit scanProgress(filesProcessed);  // Update progress counter in UI
            }
        }

        // Write to database (uses a separate DB connection named "scanner_conn")
        // ...

        // When done, jump BACK to the main thread to emit the final signal
        QMetaObject::invokeMethod(this, [this, filesProcessed]() {
            loadDatabase();                          // Reload the clean database
            emit scanFinished(filesProcessed);       // Tell UI we're done
        }, Qt::QueuedConnection);                    // QueuedConnection = cross-thread safe
    });
}
```

### Why a Separate Database Connection?

SQLite is not thread-safe by default. If the background thread used the same `QSqlDatabase` connection as the main thread, it could corrupt data. The solution:

```cpp
// On background thread: create a named connection just for this thread
QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", "scanner_conn");
db.setDatabaseName(dataDir + "/tracks.db");
// ... use it ...

// After the background thread finishes with it:
QSqlDatabase::removeDatabase("scanner_conn");  // Clean up the named connection
```

---

## 5.5 The `QDirIterator` — Recursive File Walk

```cpp
QDirIterator it(
    path,                                           // Root directory
    QStringList() << "*.mp3" << "*.flac" << "*.wav" << "*.m4a" << "*.aac" << "*.ogg",  // Name filters
    QDir::Files,                                    // Only find regular files (not dirs)
    QDirIterator::Subdirectories                    // Recurse into sub-folders
);

while (it.hasNext()) {
    QString filePath = it.next();   // Gets next matching file's full path
    // process filePath...
}
```

---

## 5.6 Signal Flow of a Complete Scan

```
User clicks "Scan Directory" in UI
         ↓
  QML calls: libraryScanner.scanDirectory(folderPath)
         ↓
  LibraryScanner::scanDirectory() emits scanStarted()
         ↓ (QML shows spinner popup)
  QtConcurrent::run launches background thread
         ↓ (background thread)
  Every 10 files: emit scanProgress(count)
         ↓ (QML updates "Found N tracks..." label)
  All files processed, inserted into DB
         ↓
  QMetaObject::invokeMethod → back to main thread
         ↓
  loadDatabase() → emit tracksAdded(allTracks)
         ↓ (connected to TrackModel::setTracks)
  TrackModel updates, QML ListView refreshes
         ↓
  emit scanFinished(total)
         ↓ (QML closes spinner popup)
```
<div class="page-break"></div>
# Chapter 6 — AudioEngine: Playing Sound with miniaudio

## 6.1 What is miniaudio?

**miniaudio** is a single-header C audio library (`third_party/miniaudio.h`). It handles:
- Audio device discovery and opening
- Audio format conversion (PCM, floating point, etc.)
- Loading and decoding audio files (mp3, flac, wav, ogg, etc.)
- A **node graph** for audio processing (equalizer, effects, mixing)
- Cross-platform: works on Linux (PulseAudio/ALSA), Windows (WASAPI), macOS (CoreAudio)

Because it's a **header-only** library, you include it in exactly **one** `.cpp` file with an implementation macro:

```cpp
// ONLY in audio_engine.cpp — defines all miniaudio function bodies
#define MINIAUDIO_IMPLEMENTATION
#include "audio_engine.h"   // which in turn includes miniaudio.h
```

All other files that use miniaudio types just `#include "audio_engine.h"` without the macro.

---

## 6.2 The AudioEngine Class Interface

```cpp
// include/audio_engine.h
class AudioEngine : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool  isPlaying READ isPlaying NOTIFY playingChanged)
    Q_PROPERTY(float position  READ position  WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(float duration  READ duration            NOTIFY durationChanged)
    Q_PROPERTY(float volume    READ volume    WRITE setVolume    NOTIFY volumeChanged)
    Q_PROPERTY(Equalizer* equalizer READ equalizer CONSTANT)

public:
    explicit AudioEngine(QObject *parent = nullptr);
    ~AudioEngine() override;

    bool  isPlaying() const;
    float position() const;   // seconds since start
    float duration() const;   // total track length in seconds
    float volume()   const;   // 0.0 = silent, 1.0 = full
    Equalizer *equalizer() const { return m_equalizer; }

public slots:
    void loadFile(const QString &filePath);
    void play();
    void pause();
    void stop();
    void setPosition(float pos);
    void setVolume(float vol);

signals:
    void playingChanged(bool isPlaying);
    void positionChanged(float position);
    void durationChanged(float duration);
    void volumeChanged(float volume);
    void playbackFinished();
    void errorOccurred(const QString &message);

private:
    ma_engine     m_engine;          // The miniaudio engine (device + graph)
    ma_sound      m_sound;           // The currently loaded audio file
    bool          m_isInitialized{false};
    bool          m_soundLoaded{false};
    float         m_volume{1.0f};
    Equalizer    *m_equalizer{nullptr};
    ma_peak_node  m_eqNodes[10];     // 10 equalizer filter nodes
    QTimer        m_progressTimer;   // Fires every 250ms to update position
};
```

---

## 6.3 Initialization: Building the Audio Pipeline

The constructor sets up the entire audio processing chain:

```cpp
AudioEngine::AudioEngine(QObject *parent)
    : QObject(parent), m_equalizer(new Equalizer(this))
{
    // Step 1: Initialize the miniaudio engine (opens the audio device)
    ma_result result = ma_engine_init(nullptr, &m_engine);
    if (result != MA_SUCCESS) {
        qWarning() << "Failed to initialize miniaudio engine.";
        return;
    }
    m_isInitialized = true;

    // Step 2: Connect Equalizer signals so we can react to EQ changes
    connect(m_equalizer, &Equalizer::enabledChanged,  this, &AudioEngine::onEqualizerEnabledChanged);
    connect(m_equalizer, &Equalizer::bandGainChanged,  this, &AudioEngine::onEqualizerBandGainChanged);

    // Step 3: Set up the 250ms progress timer
    connect(&m_progressTimer, &QTimer::timeout, this, [this]() {
        if (m_soundLoaded) {
            if (ma_sound_at_end(&m_sound)) {
                stop();
                emit playbackFinished();   // Auto-advance to next track
            } else if (isPlaying()) {
                emit positionChanged(position()); // Update progress bar
            }
        }
    });
    m_progressTimer.start(250);

    // Step 4: Build the 10-band EQ filter node chain
    ma_node_graph *pGraph    = ma_engine_get_node_graph(&m_engine);
    ma_uint32 channels       = ma_engine_get_channels(&m_engine);   // Usually 2 (stereo)
    ma_uint32 sampleRate     = ma_engine_get_sample_rate(&m_engine); // e.g., 44100 or 48000

    for (int i = 0; i < 10; ++i) {
        float freq = m_equalizer->bandFrequency(i);  // 31Hz, 62Hz, 125Hz, ..., 16kHz
        ma_peak_node_config config =
            ma_peak_node_config_init(channels, sampleRate, 0.0, 1.414, freq);
            //                        channels  sampleRate  gainDb  Q-factor  centerFreq
        ma_peak_node_init(pGraph, &config, nullptr, &m_eqNodes[i]);

        // Chain: connect output of node[i-1] into input of node[i]
        if (i > 0) {
            ma_node_attach_output_bus(&m_eqNodes[i-1], 0, &m_eqNodes[i], 0);
        }
    }

    // Connect last EQ node → speaker endpoint
    ma_node_attach_output_bus(&m_eqNodes[9], 0, ma_engine_get_endpoint(&m_engine), 0);
}
```

### The Audio Node Graph Visualized

```
Sound Source (ma_sound)
        │
        ▼
  [EQ Node: 31 Hz]        ← Peak filter at 31 Hz, gain = 0 dB initially
        │
        ▼
  [EQ Node: 62 Hz]
        │
        ▼
  [EQ Node: 125 Hz]
        │
       ...
        ▼
  [EQ Node: 16,000 Hz]
        │
        ▼
  Engine Endpoint (speakers / audio device)
```

Each `ma_peak_node` is a **peaking EQ filter** — it can boost or cut a narrow band of frequencies. The "Q-factor" (1.414 ≈ √2) controls how wide the boost/cut is.

---

## 6.4 Loading a File

```cpp
void AudioEngine::loadFile(const QString &filePath) {
    if (!m_isInitialized) return;

    // Unload any previously loaded sound
    if (m_soundLoaded) {
        ma_sound_uninit(&m_sound);
        m_soundLoaded = false;
    }

    // Load the new file (decoded = decompressed to raw PCM in memory, ASYNC = non-blocking)
    ma_result result = ma_sound_init_from_file(
        &m_engine,
        filePath.toUtf8().constData(),       // C string path
        MA_SOUND_FLAG_DECODE | MA_SOUND_FLAG_ASYNC,
        nullptr, nullptr,
        &m_sound
    );

    if (result != MA_SUCCESS) {
        emit errorOccurred("Failed to load audio file: " + filePath);
        return;
    }

    // Redirect the sound's output to the EQ chain instead of directly to speakers
    ma_node_attach_output_bus(&m_sound, 0, &m_eqNodes[0], 0);

    m_soundLoaded = true;
    ma_sound_set_volume(&m_sound, m_volume);  // Apply current volume

    float len = 0.0f;
    ma_sound_get_length_in_seconds(&m_sound, &len);
    emit durationChanged(len);   // Tell QML the total length
    emit positionChanged(0.0f);  // Reset progress bar
}
```

**`MA_SOUND_FLAG_DECODE`**: Pre-decodes the entire audio file to raw PCM. This avoids stuttering — decoding on-the-fly while playing can cause gaps.

**`MA_SOUND_FLAG_ASYNC`**: The file loading starts on a background thread immediately. The sound won't be ready instantly, but the UI thread isn't blocked.

---

## 6.5 Play, Pause, Stop

```cpp
void AudioEngine::play() {
    if (!m_soundLoaded) return;
    ma_sound_start(&m_sound);       // Begin audio output
    emit playingChanged(true);      // Update the Play/Pause button icon in QML
}

void AudioEngine::pause() {
    if (!m_soundLoaded) return;
    ma_sound_stop(&m_sound);        // Pause (keeps position)
    emit playingChanged(false);
}

void AudioEngine::stop() {
    if (m_soundLoaded) {
        ma_sound_stop(&m_sound);
        ma_sound_seek_to_pcm_frame(&m_sound, 0);  // Rewind to beginning
        emit playingChanged(false);
    }
    emit positionChanged(0.0f);     // Reset progress bar to 0
}
```

---

## 6.6 Seeking — Jumping to a Position

```cpp
void AudioEngine::setPosition(float pos) {
    if (!m_soundLoaded) return;
    if (pos < 0.0f) pos = 0.0f;

    float len = duration();
    if (len > 0.0f && pos >= len) {
        emit playbackFinished();  // Seeked past the end — treat as finished
        return;
    }

    // Convert seconds → PCM frame number
    // PCM frame = one sample per channel. At 44100 Hz, 1 second = 44100 frames.
    ma_uint32 sampleRate = ma_engine_get_sample_rate(&m_engine);
    ma_uint64 targetFrame = static_cast<ma_uint64>(pos * sampleRate);
    ma_sound_seek_to_pcm_frame(&m_sound, targetFrame);
    emit positionChanged(pos);
}
```

### Why PCM Frames?

miniaudio works in **PCM frames** (Pulse Code Modulation samples), not seconds. To seek to 30 seconds into a 44100 Hz song:
```
targetFrame = 30 * 44100 = 1,323,000
```

---

## 6.7 Querying State

```cpp
bool AudioEngine::isPlaying() const {
    if (!m_soundLoaded) return false;
    return ma_sound_is_playing(&m_sound);  // Ask miniaudio directly
}

float AudioEngine::position() const {
    if (!m_soundLoaded) return 0.0f;
    float cursor = 0.0f;
    ma_sound_get_cursor_in_seconds(&m_sound, &cursor);
    return cursor;
}

float AudioEngine::duration() const {
    if (!m_soundLoaded) return 0.0f;
    float len = 0.0f;
    ma_sound_get_length_in_seconds(&m_sound, &len);
    return len;
}

float AudioEngine::volume() const { return m_volume; }
```

---

## 6.8 Applying EQ Changes Dynamically

When the user moves an EQ slider, `Equalizer::setBandGain(index, gainDb)` is called, which emits `bandGainChanged`. `AudioEngine` catches this:

```cpp
void AudioEngine::onEqualizerBandGainChanged(int index, float gainDb) {
    if (index < 0 || index >= 10) return;

    ma_uint32 channels   = ma_engine_get_channels(&m_engine);
    ma_uint32 sampleRate = ma_engine_get_sample_rate(&m_engine);
    float freq           = m_equalizer->bandFrequency(index);

    // If EQ is globally disabled, apply 0 dB gain (flat response) regardless
    float actualGain = m_equalizer->isEnabled() ? gainDb : 0.0f;

    // Reinitialize the specific peak node with the new gain
    ma_peak2_config config = ma_peak2_config_init(
        ma_format_f32, channels, sampleRate, actualGain, 1.414, freq
    );
    ma_peak_node_reinit((const ma_peak_config *)&config, &m_eqNodes[index]);
}
```

`ma_peak_node_reinit` rebuilds the filter coefficients on-the-fly. The audio pipeline adjusts **instantly without any clicking or popping** because miniaudio smoothly transitions the coefficients.

---

## 6.9 Cleanup

```cpp
AudioEngine::~AudioEngine() {
    if (m_soundLoaded) {
        ma_sound_uninit(&m_sound);     // Release audio file resources
    }
    if (m_isInitialized) {
        ma_engine_uninit(&m_engine);   // Close audio device
    }
}
```

Always clean up in reverse order of initialization. The `ma_peak_node` instances are attached to the node graph, which is part of `m_engine`, so they are cleaned up when `ma_engine_uninit` is called.
<div class="page-break"></div>
# Chapter 7 — The Equalizer: Presets and QSettings

## 7.1 What is a Graphic Equalizer?

A **10-band graphic equalizer** lets users boost or cut 10 specific frequency bands:

| Band | Frequency | What it affects |
|------|-----------|-----------------|
| 1 | 31 Hz | Sub-bass (rumble, kick drum body) |
| 2 | 62 Hz | Bass (bass guitar, bass drum) |
| 3 | 125 Hz | Upper bass / low midrange (warmth) |
| 4 | 250 Hz | Low midrange (body of vocals) |
| 5 | 500 Hz | Midrange (nasal quality) |
| 6 | 1000 Hz | Upper midrange (presence) |
| 7 | 2000 Hz | High midrange (edge/bite) |
| 8 | 4000 Hz | Presence (clarity, articulation) |
| 9 | 8000 Hz | High frequency (air, brightness) |
| 10 | 16000 Hz | Ultra-high (shimmer, sizzle) |

Each band's gain can be adjusted from **-12 dB** (quieter) to **+12 dB** (louder) in that frequency range.

---

## 7.2 The Equalizer Class

```cpp
// include/equalizer.h
class Equalizer : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit Equalizer(QObject *parent = nullptr);

    bool isEnabled() const;

    Q_INVOKABLE int          bandCount() const;           // Returns 10
    Q_INVOKABLE float        bandGain(int index) const;   // -12.0 to +12.0 dB
    Q_INVOKABLE float        bandFrequency(int index) const; // e.g., 31.25 Hz

    Q_INVOKABLE QStringList  getPresetNames() const;
    Q_INVOKABLE bool         isCustomPreset(const QString &name) const;
    Q_INVOKABLE void         saveCustomPreset(const QString &name);
    Q_INVOKABLE void         loadPreset(const QString &name);
    Q_INVOKABLE void         deleteCustomPreset(const QString &name);

public slots:
    void setEnabled(bool enabled);
    void setBandGain(int index, float gainDb);

signals:
    void enabledChanged(bool enabled);
    void bandGainChanged(int index, float gainDb);

private:
    bool           m_enabled{false};
    QVector<float> m_frequencies;   // [31.25, 62.5, 125.0, ..., 16000.0]
    QVector<float> m_gains;         // [0.0, 0.0, 0.0, ..., 0.0] — all flat initially
};
```

---

## 7.3 Initialization

```cpp
Equalizer::Equalizer(QObject *parent) : QObject(parent), m_enabled(false) {
    // Standard ISO 1/3-octave equalizer center frequencies (starting at 31.25 Hz)
    m_frequencies = {31.25f, 62.5f, 125.0f, 250.0f, 500.0f,
                     1000.0f, 2000.0f, 4000.0f, 8000.0f, 16000.0f};
    m_gains.fill(0.0f, m_frequencies.size()); // All bands start at 0 dB (flat)
}
```

---

## 7.4 Band Gain: Read and Write

```cpp
float Equalizer::bandGain(int index) const {
    if (index >= 0 && index < m_gains.size())
        return m_gains[index];
    return 0.0f;
}

void Equalizer::setBandGain(int index, float gainDb) {
    // Clamp to -12 to +12 dB range — hard limit
    float clampedGain = fmaxf(-12.0f, fminf(12.0f, gainDb));

    if (index >= 0 && index < m_gains.size()) {
        if (m_gains[index] != clampedGain) {   // Only emit if actually changed
            m_gains[index] = clampedGain;
            emit bandGainChanged(index, clampedGain);  // AudioEngine catches this
        }
    }
}
```

`fmaxf` and `fminf` are C standard library `<math.h>` functions for `float` clamping:
```
fminf(12.0f, 15.0f) → 12.0f   (clip to max)
fmaxf(-12.0f, -20.0f) → -12.0f (clip to min)
```

---

## 7.5 Factory Presets

Built-in presets are defined as a static function (not a member variable) to avoid initialization order issues:

```cpp
static QMap<QString, QVector<float>> getFactoryPresets() {
    QMap<QString, QVector<float>> presets;
    //                              31  62  125 250 500 1k  2k  4k  8k  16k
    presets["Flat"]         = {  0,  0,  0,  0,  0,  0,  0,  0,  0,  0 };
    presets["Acoustic"]     = {  5,  5,  4,  1,  1,  1,  3,  4,  3,  2 };
    presets["Bass Booster"] = {  6,  5,  4,  2,  1,  0,  0,  0,  0,  0 };
    presets["Classical"]    = {  5,  4,  3,  2, -1, -1,  0,  2,  3,  4 };
    presets["Dance"]        = {  4,  6,  5,  0,  2,  3,  5,  4,  3,  0 };
    presets["Electronic"]   = {  4,  3,  1, -2, -3,  1,  3,  5,  4,  5 };
    presets["Pop"]          = { -1, -1,  0,  2,  4,  4,  2,  0, -1, -2 };
    presets["Rock"]         = {  5,  4,  3,  1, -1, -1,  1,  2,  3,  4 };
    return presets;
}
```

`QMap<K, V>` is Qt's sorted associative container (like `std::map`). Keys are sorted alphabetically, so `getPresetNames()` returns a naturally sorted list.

---

## 7.6 Custom Presets with QSettings

`QSettings` is Qt's cross-platform way to store user preferences. On Linux it writes INI files to `~/.config/ModernMusicPlayer/EqualizerPresets.ini`. On Windows it uses the registry.

### Saving a Custom Preset

```cpp
void Equalizer::saveCustomPreset(const QString &name) {
    if (name.isEmpty() || getFactoryPresets().contains(name))
        return;  // Can't overwrite factory presets

    QSettings settings("ModernMusicPlayer", "EqualizerPresets");
    settings.beginGroup(name);          // Creates a [name] section in the INI
    settings.beginWriteArray("bands");  // Creates an indexed list
    for (int i = 0; i < m_gains.size(); ++i) {
        settings.setArrayIndex(i);
        settings.setValue("gain", m_gains[i]);
    }
    settings.endArray();
    settings.endGroup();
}
```

The resulting INI file looks like:
```ini
[MyPreset]
bands\size=10
bands\1\gain=6
bands\2\gain=4
...
```

### Loading a Preset (Factory or Custom)

```cpp
void Equalizer::loadPreset(const QString &name) {
    // Check factory presets first
    auto factory = getFactoryPresets();
    if (factory.contains(name)) {
        const auto &gains = factory[name];
        for (int i = 0; i < gains.size() && i < m_gains.size(); ++i) {
            setBandGain(i, gains[i]);   // Each call emits bandGainChanged → AudioEngine updates
        }
        return;
    }

    // Otherwise load from QSettings (user-saved)
    QSettings settings("ModernMusicPlayer", "EqualizerPresets");
    if (settings.childGroups().contains(name)) {
        settings.beginGroup(name);
        int size = settings.beginReadArray("bands");
        for (int i = 0; i < size && i < m_gains.size(); ++i) {
            settings.setArrayIndex(i);
            float gain = settings.value("gain").toFloat();
            setBandGain(i, gain);
        }
        settings.endArray();
        settings.endGroup();
    }
}
```

### Deleting a Custom Preset

```cpp
void Equalizer::deleteCustomPreset(const QString &name) {
    if (!isCustomPreset(name)) return;  // Safety: can't delete factory presets

    QSettings settings("ModernMusicPlayer", "EqualizerPresets");
    settings.beginGroup(name);
    settings.remove("");   // Empty string = remove everything under this group
    settings.endGroup();
}
```

---

## 7.7 Getting All Preset Names (Factory + Custom)

```cpp
QStringList Equalizer::getPresetNames() const {
    QStringList names = getFactoryPresets().keys();   // ["Acoustic", "Bass Booster", ...]

    QSettings settings("ModernMusicPlayer", "EqualizerPresets");
    names.append(settings.childGroups());             // Add custom preset names

    names.removeDuplicates();  // Safety: no duplicates
    names.sort();              // Alphabetical order

    return names;
}
```

In QML, this method is called to populate the preset dropdown:
```qml
ComboBox {
    model: audioEngine.equalizer.getPresetNames()
    onActivated: audioEngine.equalizer.loadPreset(currentText)
}
```

---

## 7.8 The Enable/Disable Toggle

When the user turns the EQ on or off:
```cpp
void Equalizer::setEnabled(bool enabled) {
    if (m_enabled != enabled) {
        m_enabled = enabled;
        emit enabledChanged(m_enabled);
    }
}
```

`AudioEngine::onEqualizerEnabledChanged` catches this and re-applies all bands:
```cpp
void AudioEngine::onEqualizerEnabledChanged(bool enabled) {
    for (int i = 0; i < 10; ++i) {
        onEqualizerBandGainChanged(i, m_equalizer->bandGain(i));
        // This function reads m_equalizer->isEnabled() to decide whether to
        // apply the stored gain or force 0 dB
    }
}
```

If EQ is disabled, `actualGain = 0.0f` regardless of stored values — the filter is flat.
<div class="page-break"></div>
# Chapter 8 — CoverArtProvider: On-Demand Album Art

## 8.1 The Problem

QML's `Image` element can display images from files or URLs. But album art is **embedded inside audio files** — it's not a separate `.jpg` on disk. We need a way for QML to request album art using a track's file path and get back a `QImage`.

Qt solves this with `QQuickImageProvider` — a class you register with the QML engine. When QML requests an image with the `image://` scheme, Qt routes the request to your provider.

---

## 8.2 How the URL Scheme Works

```qml
// In QML — request album art for a specific track:
Image {
    source: "image://musiccover/" + track.filePath
    //       ↑ scheme+id  ↑ provider name  ↑ the "id" passed to requestImage()
}
```

The URL `image://musiccover/home/user/music/song.mp3` tells Qt:
- Use the image provider registered as `"musiccover"`
- Pass `"/home/user/music/song.mp3"` as the `id` parameter

---

## 8.3 The CoverArtProvider Class

```cpp
// include/cover_art_provider.h
#include <QQuickImageProvider>
#include <QImage>

class CoverArtProvider : public QQuickImageProvider {
public:
    CoverArtProvider();
    QImage requestImage(const QString &id, QSize *size,
                        const QSize &requestedSize) override;
};
```

Note: `CoverArtProvider` does **not** inherit from `QObject`. It inherits from `QQuickImageProvider` instead. It therefore has **no signals or slots** and does not use `Q_OBJECT`.

---

## 8.4 Full Implementation

```cpp
CoverArtProvider::CoverArtProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)  // We return QImage objects
{}

QImage CoverArtProvider::requestImage(const QString &id, QSize *size,
                                       const QSize &requestedSize)
{
    QString filePath = id;   // id is exactly the path after "image://musiccover/"
    QImage image;

    // Helper lambda: scale and report size before returning
    auto returnImage = [&]() {
        if (size) *size = image.size();
        if (requestedSize.width() > 0 && requestedSize.height() > 0) {
            image = image.scaled(requestedSize, Qt::KeepAspectRatio,
                                 Qt::SmoothTransformation);
        }
        return image;
    };

    // --- MP3: Read APIC (Attached Picture) frame from ID3v2 tag ---
    if (filePath.endsWith(".mp3", Qt::CaseInsensitive)) {
        TagLib::MPEG::File mpegFile(filePath.toUtf8().constData());
        if (mpegFile.hasID3v2Tag()) {
            TagLib::ID3v2::Tag *id3v2tag = mpegFile.ID3v2Tag();
            if (id3v2tag) {
                auto frameList = id3v2tag->frameListMap()["APIC"];
                if (!frameList.isEmpty()) {
                    auto frame = static_cast<TagLib::ID3v2::AttachedPictureFrame *>(
                        frameList.front());
                    // frame->picture() returns raw JPEG/PNG bytes
                    image.loadFromData(
                        (const uchar *)frame->picture().data(),
                        frame->picture().size()
                    );
                }
            }
        }
    }
    // --- FLAC: Read from FLAC picture list ---
    else if (filePath.endsWith(".flac", Qt::CaseInsensitive)) {
        TagLib::FLAC::File flacFile(filePath.toUtf8().constData());
        if (flacFile.isValid() && !flacFile.pictureList().isEmpty()) {
            auto picture = flacFile.pictureList().front();
            image.loadFromData(
                (const uchar *)picture->data().data(),
                picture->data().size()
            );
        }
    }
    // --- M4A: Read "covr" item from MP4 tag ---
    else if (filePath.endsWith(".m4a", Qt::CaseInsensitive)) {
        TagLib::MP4::File mp4File(filePath.toUtf8().constData());
        if (mp4File.isValid() && mp4File.tag()) {
            auto itemList = mp4File.tag()->itemMap();
            if (itemList.contains("covr")) {
                auto covrList = itemList["covr"].toCoverArtList();
                if (!covrList.isEmpty()) {
                    auto picture = covrList.front();
                    image.loadFromData(
                        (const uchar *)picture.data().data(),
                        picture.data().size()
                    );
                }
            }
        }
    }

    // Fallback: if no art found (or null image), return a dark placeholder
    if (image.isNull()) {
        image = QImage(200, 200, QImage::Format_RGB32);
        image.fill(QColor("#33333b"));  // dark neutral gray
    }

    return returnImage();
}
```

---

## 8.5 Registering the Provider in main.cpp

```cpp
QQmlApplicationEngine engine;
engine.addImageProvider(QLatin1String("musiccover"), new CoverArtProvider);
```

This registers the provider under the name `"musiccover"`, which matches the `image://musiccover/` URL scheme in QML. After this line, any QML `Image` with a matching source URL will automatically call `CoverArtProvider::requestImage()`.

---

## 8.6 Optimizing: sourceSize in QML

In the queue drawer and track list, album art is shown at small sizes (40×40 px). Without a `sourceSize`, Qt would load the full 500×500 JPEG and scale it in the GPU. With it:

```qml
Image {
    source: "image://musiccover/" + modelData.filePath
    Layout.preferredWidth: 40
    Layout.preferredHeight: 40
    fillMode: Image.PreserveAspectCrop
    asynchronous: true          // Load on background thread so list stays smooth
    sourceSize: Qt.size(100, 100) // Ask provider to pre-scale to 100x100
}
```

`sourceSize` is passed as `requestedSize` to `requestImage()`. The `returnImage` lambda scales the decoded image to this size before returning — saving GPU memory and improving render performance.
<div class="page-break"></div>
# Chapter 9 — main.cpp: Wiring Everything Together

`main.cpp` is the entry point of the application. It is intentionally short — its only job is to **create the backend objects, connect them to each other, expose them to QML, and launch the engine**.

## 9.1 The Full main.cpp Annotated

```cpp
#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "audio_engine.h"
#include "cover_art_provider.h"
#include "library_scanner.h"
#include "track_model.h"

#include <taglib/tdebuglistener.h>

// ─── Step 1: Silence TagLib's debug output ───────────────────────────────────
// TagLib prints diagnostic messages to the console. This custom listener
// swallows them so our terminal stays clean during development.
class SilentTagLibListener : public TagLib::DebugListener {
public:
    void printMessage(const TagLib::String &msg) override {
        // Intentionally empty — suppress all messages
    }
};

int main(int argc, char *argv[]) {
    // Register the silent listener before anything else runs
    static SilentTagLibListener silentListener;
    TagLib::setDebugListener(&silentListener);

    // ─── Step 2: High DPI support for Qt5 ───────────────────────────────────
    // Qt6 enables this automatically; Qt5 needs an explicit attribute.
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    // ─── Step 3: Force the Material Dark theme ──────────────────────────────
    // These environment variables must be set BEFORE QApplication is created.
    // If set after, they have no effect because the style is loaded at startup.
    qputenv("QT_QUICK_CONTROLS_STYLE",              "Material");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME",     "Dark");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_BACKGROUND", "#0a0a0c");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_ACCENT",     "Purple");

    // ─── Step 4: Create the Qt application object ───────────────────────────
    // QApplication (not QCoreApplication) is needed for Qt Quick / GUI apps.
    QApplication app(argc, argv);

    // ─── Step 5: Register the Equalizer type with QML ───────────────────────
    // AudioEngine exposes an 'equalizer' property of type Equalizer*.
    // QML needs to know this type exists even though it can never CREATE one.
    // qmlRegisterUncreatableType tells QML: "this type exists, you can hold a
    // pointer to it and call its Q_INVOKABLE methods, but you cannot write
    // 'Equalizer { }' in QML".
    qmlRegisterUncreatableType<Equalizer>(
        "com.musicplayer", 1, 0,
        "Equalizer",
        "Equalizer cannot be created in QML"
    );

    // ─── Step 6: Create backend instances (on the stack — no new/delete) ────
    AudioEngine   audioEngine;
    LibraryScanner libraryScanner;
    TrackModel    trackModel;

    // ─── Step 7: Connect the scanner to the model ───────────────────────────
    // When scanning finishes and emits tracksAdded(vector),
    // trackModel automatically calls setTracks(vector) and updates QML.
    QObject::connect(&libraryScanner, &LibraryScanner::tracksAdded,
                     &trackModel,     &TrackModel::setTracks);

    // ─── Step 8: Create the QML engine ──────────────────────────────────────
    QQmlApplicationEngine engine;

    // Register the image provider for album art
    // After this, QML Image sources like "image://musiccover/path/to/song.mp3"
    // will automatically call CoverArtProvider::requestImage()
    engine.addImageProvider(QLatin1String("musiccover"), new CoverArtProvider);

    // ─── Step 9: Expose backend objects to QML ──────────────────────────────
    // These names become global JavaScript identifiers in ALL QML files.
    // QML can call methods: audioEngine.play()
    // QML can read properties: audioEngine.isPlaying
    // QML can connect to signals: Connections { target: audioEngine ... }
    engine.rootContext()->setContextProperty("audioEngine",    &audioEngine);
    engine.rootContext()->setContextProperty("libraryScanner", &libraryScanner);
    engine.rootContext()->setContextProperty("trackModel",     &trackModel);

    // ─── Step 10: Load the root QML file ────────────────────────────────────
    const QUrl url(QStringLiteral("qrc:/qml/main.qml"));

    // Connect objectCreated to detect if loading failed (e.g., QML parse error)
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated, &app,
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);   // QML failed to load — exit
        },
        Qt::QueuedConnection
    );
    engine.load(url);   // Starts QML parsing and instantiation

    // ─── Step 11: Run the event loop ────────────────────────────────────────
    // app.exec() blocks here until the user closes the window.
    // All signals, slots, timers, and the 250ms progress timer run within this loop.
    return app.exec();
}
```

---

## 9.2 Why Stack Allocation?

```cpp
AudioEngine   audioEngine;     // Stack
LibraryScanner libraryScanner; // Stack
TrackModel    trackModel;      // Stack
```

All three backend objects are created on the stack (no `new`). This means:
- When `main()` returns, they are automatically destroyed in reverse order
- miniaudio and SQLite are properly cleaned up in destructors
- No risk of memory leaks

If they were heap-allocated (`new AudioEngine()`), we'd need `delete` or a smart pointer.

---

## 9.3 The Signal Connection in main.cpp

```cpp
QObject::connect(&libraryScanner, &LibraryScanner::tracksAdded,
                 &trackModel,     &TrackModel::setTracks);
```

This is the **only** inter-object connection made in `main.cpp`. Both objects are completely ignorant of each other — `LibraryScanner` doesn't `#include "track_model.h"` and vice versa. The coupling is established here, at the composition root.

This is the **dependency injection** / **Hollywood principle**: "Don't call us. We'll call you." The scanner just emits — it doesn't care who listens.

---

## 9.4 Context Properties vs. qmlRegisterType

There are two ways to expose C++ to QML:

| Method | What It Does | Example |
|--------|-------------|---------|
| `setContextProperty` | Exposes a **single instance** as a global name | `audioEngine.play()` |
| `qmlRegisterType` | Lets QML **create new instances** of a type | `MyType { }` in QML |
| `qmlRegisterUncreatableType` | Lets QML **hold a pointer** to a type but not create one | Used for `Equalizer*` |

We use `setContextProperty` for all three backend objects because there should be exactly **one** audio engine and **one** track model. QML doesn't need to create its own — it uses the single shared instance.

---

## 9.5 qputenv — Theme Configuration

```cpp
qputenv("QT_QUICK_CONTROLS_STYLE",              "Material");
qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME",     "Dark");
qputenv("QT_QUICK_CONTROLS_MATERIAL_BACKGROUND", "#0a0a0c");
qputenv("QT_QUICK_CONTROLS_MATERIAL_ACCENT",     "Purple");
```

These **must** be set before `QApplication` is constructed. The Qt Quick Controls style system reads them during initialization. Setting them afterward has no effect.

Without these, if the user's OS is set to a Light theme, Qt would override the app's dark appearance. The `Dark` override ensures consistent appearance regardless of system theme.
<div class="page-break"></div>
# Chapter 10 — QML Language Fundamentals for C++ Developers

QML (Qt Modeling Language) is a **declarative language** for building UIs. Instead of writing imperative code that says "create a button, then set its color, then position it", you declare what the UI should look like as a **tree of nested objects**.

---

## 10.1 Your First QML File

```qml
import QtQuick 2.15        // Core QML types (Rectangle, Text, MouseArea, etc.)
import QtQuick.Controls 2.15  // Button, Slider, ComboBox, etc.

// Root Item — every QML file has exactly one root item
Rectangle {
    width: 400
    height: 300
    color: "#1a1a2e"        // Dark blue background

    Text {
        anchors.centerIn: parent  // Center inside the Rectangle
        text: "Hello, QML!"
        color: "white"
        font.pixelSize: 24
    }
}
```

Key observations:
- **No semicolons** — QML uses newlines and braces
- **Properties** are set with `property: value` (not `setProperty(value)`)
- **Hierarchy** is expressed by nesting — `Text` is a child of `Rectangle`
- **`parent`** refers to the immediate parent item
- `anchors` is a powerful layout system that positions items relative to their parent

---

## 10.2 Types You'll See in This Project

| QML Type | Purpose |
|----------|---------|
| `Rectangle` | Colored, rounded, or bordered box |
| `Text`, `Label` | Displays text |
| `Image` | Displays images (including `image://` custom providers) |
| `Item` | Invisible container (no visual) |
| `RowLayout`, `ColumnLayout`, `GridLayout` | Automatic layout managers |
| `ListView` | Scrollable list bound to a model |
| `Repeater` | Creates N items from a model (for fixed grids) |
| `Button`, `ToolButton`, `RoundButton` | Clickable buttons |
| `Slider` | Draggable value input |
| `ComboBox` | Dropdown selector |
| `Popup` | Floating overlay (modal or non-modal) |
| `Drawer` | Sliding panel from a screen edge |
| `TabBar`, `TabButton` | Tabbed navigation |
| `ScrollView`, `Flickable` | Scrollable content |
| `BusyIndicator` | Spinning loading animation |
| `Shortcut` | Maps keyboard sequences to actions |

---

## 10.3 Properties: Built-in and Custom

Every QML item has built-in properties (`width`, `height`, `color`, `visible`, etc.). You can define your own:

```qml
Rectangle {
    // Custom property definition
    property string currentArtist: "Unknown"
    property bool isSidebarVisible: true
    property int repeatCount: 0

    // Usage: properties are accessed by name
    Text { text: parent.currentArtist }
}
```

**Property binding** — when a property references another, it automatically updates:
```qml
Rectangle {
    width: 200
    height: width * 0.5    // height is always half of width — auto-updates!
}
```

---

## 10.4 id — Addressing Items by Name

Every item can have a unique `id` that lets other items reference it:

```qml
ApplicationWindow {
    id: window    // Other items refer to this as "window"

    Slider {
        id: progressSlider
        value: audioEngine.position   // Binds to C++ property
    }

    Text {
        // Reads the slider's value
        text: "Position: " + Math.floor(progressSlider.value)
    }
}
```

`id` is **not** a property. It is a compile-time binding name scoped to the current QML document.

---

## 10.5 Signals and Handlers in QML

C++ signals become `on<SignalName>` handlers in QML:

```qml
// C++ signal: void playingChanged(bool isPlaying)
// QML handler: onPlayingChanged
Button {
    onClicked: {    // Built-in MouseArea signal "clicked"
        if (audioEngine.isPlaying)
            audioEngine.pause()
        else
            audioEngine.play()
    }
}
```

For signals from objects that aren't the direct parent, use `Connections`:

```qml
Connections {
    target: libraryScanner          // Which C++ object to watch
    function onScanStarted() {      // Modern Qt5.15+ syntax
        scanningPopup.open()
    }
    function onScanProgress(count) {
        scanningLabel.text = "Found " + count + " Tracks..."
    }
    function onScanFinished(total) {
        scanningPopup.close()
    }
}
```

---

## 10.6 Functions in QML

JavaScript functions live inside QML items:

```qml
Rectangle {
    id: playbackBar

    // A helper function — called like JS: playbackBar.formatTime(354)
    function formatTime(seconds) {
        if (!seconds || isNaN(seconds)) return "00:00";
        let m = Math.floor(seconds / 60);
        let s = Math.floor(seconds % 60);
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    Text { text: playbackBar.formatTime(audioEngine.duration) }
}
```

---

## 10.7 ListView and Delegates

`ListView` displays a scrollable list from a model. The `delegate` defines what each row looks like:

```qml
ListView {
    width: 400
    height: 600
    model: trackModel       // C++ QAbstractListModel — roles become JS vars

    delegate: Rectangle {
        width: ListView.view.width
        height: 60
        color: "#22222b"

        Column {
            Text {
                text: title    // "title" role from TrackModel::roleNames()
                color: "white"
            }
            Text {
                text: artist   // "artist" role
                color: "#aaa"
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: window.playTrackAtIndex(index, "songs")
            //                                 ↑ built-in "index" in delegate
        }
    }
}
```

Inside a delegate:
- `index` — the row number (0-based)
- `model` — the data for this row (rarely used directly)
- Role names (e.g., `title`, `artist`) — available as plain variables

---

## 10.8 Anchors — The Layout System

`anchors` is how you position items relative to their parent or siblings:

```qml
Item {
    width: 400; height: 400

    Rectangle {
        anchors.fill: parent         // Fill the parent completely
        color: "red"
    }

    Rectangle {
        width: 100; height: 100
        anchors.centerIn: parent     // Center in parent
        color: "blue"
    }

    Rectangle {
        width: 50; height: 50
        anchors.top: parent.top      // Stick to top
        anchors.right: parent.right  // Stick to right
        anchors.margins: 10          // 10px gap from edges
        color: "green"
    }
}
```

You can anchor to `parent.top`, `parent.bottom`, `parent.left`, `parent.right`, `parent.horizontalCenter`, `parent.verticalCenter`, or to another item's edges.

---

## 10.9 Layouts vs Anchors

For multiple children that need to be arranged together, use `RowLayout` / `ColumnLayout`:

```qml
RowLayout {
    anchors.fill: parent
    spacing: 10

    Button { text: "Prev";  Layout.preferredWidth: 40 }
    Button { text: "Play";  Layout.fillWidth: true }  // This one takes remaining space
    Button { text: "Next";  Layout.preferredWidth: 40 }
}
```

`Layout.fillWidth: true` — expand to fill remaining space.
`Layout.preferredWidth: N` — request a specific size.
`Layout.alignment: Qt.AlignHCenter` — align within cell.

---

## 10.10 Animations and Behaviors

QML makes animation very easy:

```qml
Rectangle {
    color: mouseArea.containsMouse ? "#2a2a35" : "transparent"
    radius: 6

    // Whenever "color" changes, animate the transition over 250ms
    Behavior on color {
        ColorAnimation { duration: 250 }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true        // Enable containsMouse
    }
}
```

`NumberAnimation`, `ColorAnimation`, `OpacityAnimator` — all work the same way. Wrap a property change in a `Behavior` and it animates automatically.

---

## 10.11 Importing Other QML Files

When `main.qml` uses `LibraryView { ... }`, it imports `LibraryView.qml` from the same directory. No explicit `import` statement is needed — **all `.qml` files in the same directory are automatically available by their filename** (minus `.qml`).

```qml
// In main.qml — these are loaded from qml/LibraryView.qml, qml/NowPlayingView.qml
LibraryView {
    anchors.fill: parent
}

NowPlayingView {
    anchors.fill: parent
}
```
<div class="page-break"></div>
# Chapter 11 — main.qml: The Root Window

`main.qml` is the root of the entire UI. It is 787 lines and contains:
- The `ApplicationWindow` (the OS window)
- A custom title bar (because the window is frameless)
- Global playback state (current track, queue, queue index)
- The playback bar (bottom controls)
- All popups: equalizer, volume, now-playing, shortcuts, scanning progress
- The queue drawer
- Keyboard shortcuts

---

## 11.1 ApplicationWindow and Frameless Mode

```qml
ApplicationWindow {
    id: window
    width: 1260
    height: 768
    visible: true
    title: qsTr("Modern Music Player")

    // FramelessWindowHint removes the OS title bar and window chrome
    flags: Qt.Window | Qt.FramelessWindowHint

    // Material Dark theme
    Material.theme: Material.Dark
    Material.accent: Material.Purple
    color: "#0a0a0c"   // Deep near-black background
```

`Qt.FramelessWindowHint` removes the OS-provided title bar, giving us full control over how the window looks. The tradeoff is we must implement our own:
- Title bar with window buttons
- Drag-to-move
- Minimize/Maximize/Close buttons

---

## 11.2 Global State Properties

```qml
// These are visible to ALL child QML files (LibraryView, NowPlayingView etc.)
property string currentPlayingTitle:  "No Song Playing"
property string currentPlayingArtist: ""
property string currentPlayingPath:   ""
property var    playbackQueue:        []    // Array of track objects
property int    currentQueueIndex:    -1   // -1 means nothing playing
property bool   repeatMode:           false
```

Because these are declared on `window` (the root `ApplicationWindow` with `id: window`), any child QML file can read from or write to `window.currentPlayingTitle` etc.

---

## 11.3 playTrackAtIndex — The Core Playback Function

```qml
function playTrackAtIndex(idx, contextCategory) {
    if (idx < 0) return;

    // If a category context is provided, rebuild the queue from the current
    // visible trackModel rows (so "All Songs", "Artist: Queen", etc. each
    // generate their own queue)
    if (contextCategory) {
        let newQueue = [];
        for (var i = 0; i < trackModel.rowCount(); i++) {
            newQueue.push(trackModel.get(i));   // Returns a JS object per row
        }
        playbackQueue = newQueue;
        currentQueueIndex = idx;
    } else {
        currentQueueIndex = idx;  // Navigation within existing queue
    }

    if (currentQueueIndex < 0 || currentQueueIndex >= playbackQueue.length) return;

    var track = playbackQueue[currentQueueIndex];
    if (!track) return;

    // Update the "Now Playing" display state
    currentPlayingTitle  = track.title;
    currentPlayingArtist = track.artist;
    currentPlayingPath   = track.filePath;

    // Tell the audio engine to load and play
    audioEngine.loadFile(track.filePath);
    audioEngine.play();
}
```

**Two modes:**
1. `playTrackAtIndex(5, "songs")` — rebuild queue from current view, play row 5
2. `playTrackAtIndex(6)` — navigate to position 6 in the **existing** queue (used by Prev/Next)

---

## 11.4 Auto-Advance on Track End

```qml
Connections {
    target: audioEngine
    function onPlaybackFinished() {
        if (repeatMode) {
            audioEngine.setPosition(0);
            audioEngine.play();
        } else {
            // Auto-advance to next track unless we're at the end
            if (currentQueueIndex >= 0 && currentQueueIndex < playbackQueue.length - 1) {
                playTrackAtIndex(currentQueueIndex + 1);
            }
        }
    }
}
```

This runs every time miniaudio signals that a track has ended (the 250ms timer in `AudioEngine` detects `ma_sound_at_end`).

---

## 11.5 The Custom Title Bar

```qml
Rectangle {
    id: titleBar
    Layout.fillWidth: true
    Layout.preferredHeight: 35
    color: "transparent"

    // Makes the window draggable (required because we removed the OS title bar)
    DragHandler {
        onActiveChanged: if (active) window.startSystemMove()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 15; anchors.rightMargin: 10

        // App title text
        Label {
            text: window.title
            color: "white"
            font.bold: true; font.pixelSize: 14
            Layout.fillWidth: true
        }

        // Window control buttons
        ToolButton {
            icon.source: "qrc:/qml/icons/minimize.svg"
            onClicked: window.showMinimized()
        }
        ToolButton {
            icon.source: "qrc:/qml/icons/maximize.svg"
            onClicked: {
                if (window.visibility === Window.Maximized)
                    window.showNormal()
                else
                    window.showMaximized()
            }
        }
        ToolButton {
            icon.source: "qrc:/qml/icons/close.svg"
            onClicked: window.close()
        }
    }
}
```

`window.startSystemMove()` — tells the OS to handle dragging the window. This is more reliable than manually tracking mouse positions.

---

## 11.6 The Keyboard Shortcut System

```qml
Shortcut { sequence: "Space";       onActivated: audioEngine.isPlaying ? audioEngine.pause() : audioEngine.play() }
Shortcut { sequence: "Ctrl+Left";   onActivated: playTrackAtIndex(currentQueueIndex - 1) }
Shortcut { sequence: "Ctrl+Right";  onActivated: playTrackAtIndex(currentQueueIndex + 1) }
Shortcut { sequence: "Left";        onActivated: audioEngine.setPosition(audioEngine.position - 10.0) }
Shortcut { sequence: "Right";       onActivated: audioEngine.setPosition(audioEngine.position + 10.0) }
Shortcut { sequence: "Up";          onActivated: audioEngine.volume = Math.min(1.0, audioEngine.volume + 0.1) }
Shortcut { sequence: "Down";        onActivated: audioEngine.volume = Math.max(0.0, audioEngine.volume - 0.1) }
Shortcut { sequence: "Ctrl+M";      onActivated: { /* Toggle mute */ } }
Shortcut { sequence: "Ctrl+P";      onActivated: queueDrawer.visible = !queueDrawer.visible }
Shortcut { sequence: "F";           onActivated: libraryView.isSidebarVisible = !libraryView.isSidebarVisible }
Shortcut { sequence: "Ctrl+Q";      onActivated: Qt.quit() }
```

`Qt.ApplicationShortcut` context means the shortcut works even when focus is inside a text input. Without it, pressing Space while a button is focused would activate both the button AND the shortcut.

---

## 11.7 The Bottom Playback Bar

This is the persistent control bar at the bottom (80px tall, always visible):

```qml
Rectangle {
    id: playbackBar
    width: parent.width; height: 80
    anchors.bottom: parent.bottom
    color: "#18181c"

    function formatTime(seconds) {
        if (!seconds || isNaN(seconds)) return "00:00";
        let m = Math.floor(seconds / 60);
        let s = Math.floor(seconds % 60);
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    RowLayout {
        // Expand/Collapse Now Playing overlay button
        ToolButton { icon.source: nowPlayingPopup.opened ? "expand_down.svg" : "expand_up.svg"
                     onClicked: nowPlayingPopup.opened ? nowPlayingPopup.close() : nowPlayingPopup.open() }

        // Previous / Play-Pause / Next
        RoundButton { icon.source: "prev.svg";  onClicked: playTrackAtIndex(currentQueueIndex - 1) }
        RoundButton {
            icon.source: audioEngine.isPlaying ? "pause.svg" : "play.svg"
            onClicked: {
                if (currentQueueIndex === -1 && playbackQueue.length > 0)
                    playTrackAtIndex(0)   // Auto-start first track
                else
                    audioEngine.isPlaying ? audioEngine.pause() : audioEngine.play()
            }
        }
        RoundButton { icon.source: "next.svg";  onClicked: playTrackAtIndex(currentQueueIndex + 1) }

        // Current time
        Text { text: playbackBar.formatTime(audioEngine.position); color: "white" }

        // Seek slider (binds bidirectionally to audioEngine.position)
        Slider {
            Layout.fillWidth: true
            from: 0; to: audioEngine.duration
            value: audioEngine.position
            onMoved: audioEngine.position = value   // WRITE triggers setPosition()
        }

        // Total duration
        Text { text: playbackBar.formatTime(audioEngine.duration); color: "white" }

        // Volume
        ToolButton { onClicked: window.showVolumePopup(this) }

        // Equalizer
        ToolButton { onClicked: eqPopup.open() }

        // Queue
        ToolButton { onClicked: queueDrawer.open() }
    }
}
```

---

## 11.8 The Queue Drawer

```qml
Drawer {
    id: queueDrawer
    edge: Qt.RightEdge        // Slides in from the right
    width: Math.min(window.width * 0.4, 400)
    height: parent.height

    ListView {
        model: window.playbackQueue    // The JS array of track objects

        delegate: ItemDelegate {
            // Only show tracks at or after the current position
            property bool isVisibleItem: index >= window.currentQueueIndex
            height: isVisibleItem ? 60 : 0
            opacity: isVisibleItem ? 1.0 : 0.0

            // Smooth height/opacity animation as items enter/leave view
            Behavior on height  { NumberAnimation { duration: 300 } }
            Behavior on opacity { NumberAnimation { duration: 250 } }

            // Highlight the currently playing track with a blue left border
            background: Rectangle {
                color: index === window.currentQueueIndex ? "#2a2a35" : "transparent"
                Rectangle {
                    width: 4; height: parent.height
                    anchors.left: parent.left
                    color: "#0078d7"
                    visible: index === window.currentQueueIndex
                }
            }

            onClicked: window.playTrackAtIndex(index)
        }
    }
}
```
<div class="page-break"></div>
# Chapter 12 — LibraryView.qml: The Main Library Browser

## 12.1 Overview

`LibraryView.qml` is the heart of the application's UI. It shows the user's music library in a tiled grid layout with a collapsible left sidebar for category filtering. It has 5 view modes:

| Mode | What it shows | How it navigates |
|------|--------------|-----------------|
| **Tracks** | Every song as a tile | Click → play immediately |
| **Artists** | One circular tile per artist | Click → drill down to artist's songs |
| **Albums** | One square tile per album | Click → drill down to album's songs |
| **Folders** | One tile per filesystem folder | Click → drill down to folder's songs |
| **Collections** | Top-level folder groupings | Click → drill down to collection's songs |

---

## 12.2 The Component Layout

```
┌─────────────────────────────────────────────────────┐
│  RowLayout (fills entire LibraryView area)          │
│                                                     │
│  ┌──────────────┐  ┌────────────────────────────┐  │
│  │  Sidebar     │  │  Content Area               │  │
│  │  (200px)     │  │                             │  │
│  │  - Tracks    │  │  [Breadcrumb / Title Bar]   │  │
│  │  - Artists   │  │                             │  │
│  │  - Albums    │  │  StackView                  │  │
│  │  - Folders   │  │  ┌──────────────────────┐  │  │
│  │  - Collections│ │  │ GridView (tiles)      │  │  │
│  │              │  │  │ (track/artist/album/  │  │  │
│  └──────────────┘  │  │  folder/collection)   │  │  │
│  (animates to 0    │  └──────────────────────┘  │  │
│   width when       └────────────────────────────┘  │
│   hidden)                                           │
└─────────────────────────────────────────────────────┘
```

---

## 12.3 State Properties

```qml
Item {
    id: libraryView
    property string activeCategoryName: "All Tracks"  // Displayed in the breadcrumb
    property string categoryContext:    "All Tracks"  // "All Tracks"|"Artists"|"Albums"|"Folders"|"Collections"
    property bool   isSidebarVisible:   true          // Controlled by "F" shortcut and toggle button
```

These three properties drive the entire view. When `categoryContext` changes, the correct grid component is pushed onto the `StackView`.

---

## 12.4 The Collapsible Sidebar

```qml
Rectangle {
    id: sidebarRect
    // When isSidebarVisible is false, width animates to 0 pixels
    Layout.preferredWidth: isSidebarVisible ? 200 : 0
    Layout.fillHeight: true
    color: "#18181c"
    radius: 12
    clip: true   // IMPORTANT: clips children during animation so they don't overflow
    visible: Layout.preferredWidth > 0

    // Smooth 250ms animation whenever width changes
    Behavior on Layout.preferredWidth {
        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
    }

    // Category buttons built from a model (no duplicated code!)
    Repeater {
        model: [
            { name: "Tracks",      ctx: "All Tracks"   },
            { name: "Artists",     ctx: "Artists"      },
            { name: "Albums",      ctx: "Albums"       },
            { name: "Folders",     ctx: "Folders"      },
            { name: "Collections", ctx: "Collections"  }
        ]
        delegate: ItemDelegate {
            property bool isActive: libraryView.categoryContext === modelData.ctx

            // Active item gets blue left bar + bolder text
            background: Rectangle {
                color: parent.isActive ? "#2a2a35" : (parent.hovered ? "#22222b" : "transparent")
                Rectangle {
                    width: 4; height: parent.height
                    anchors.left: parent.left
                    color: "#0078d7"
                    visible: parent.parent.isActive
                }
            }

            onClicked: {
                libraryView.categoryContext = modelData.ctx
                mainStack.clear()  // Remove any drilled-down views

                if      (modelData.name === "Tracks")      mainStack.push(trackGridComponent)
                else if (modelData.name === "Artists")     mainStack.push(artistGridComponent)
                else if (modelData.name === "Albums")      mainStack.push(albumGridComponent)
                else if (modelData.name === "Folders")     mainStack.push(folderGridComponent)
                else if (modelData.name === "Collections") mainStack.push(collectionGridComponent)
            }
        }
    }
}
```

---

## 12.5 StackView — Navigation

`StackView` provides the drill-down navigation. Think of it as a stack of pages: push to go deeper, pop to go back.

```qml
StackView {
    id: mainStack
    Layout.fillWidth: true
    Layout.fillHeight: true
    initialItem: trackGridComponent   // Start on the tracks view
}
```

When the user clicks an Artist tile:
```qml
onClicked: {
    libraryView.activeCategoryName = modelData.name  // "Queen"
    trackModel.filterByArtist(modelData.name)        // Filter C++ model
    mainStack.push(trackGridComponent)               // Push song grid on stack
}
```

The back button pops this:
```qml
ToolButton {
    visible: mainStack.depth > 1   // Only show when there is something to pop back to
    onClicked: {
        mainStack.pop()
        libraryView.activeCategoryName = libraryView.categoryContext
    }
}
```

---

## 12.6 The Track Grid (trackGridComponent)

```qml
Component {
    id: trackGridComponent
    GridView {
        model: trackModel   // The C++ QAbstractListModel
        cellWidth: 160
        cellHeight: 200
        clip: true
        cacheBuffer: 1000   // Pre-render items 1000px outside visible area for smooth scrolling

        delegate: Item {
            width: 160; height: 200

            Rectangle {
                anchors.fill: parent
                anchors.margins: 10
                color: "#202025"; radius: 8

                Rectangle {
                    id: artRect
                    width: parent.width - 20; height: width
                    color: "#33333b"; radius: 8; clip: true

                    // Cover art with fallback "?" placeholder
                    Image {
                        anchors.fill: parent
                        // "image://musiccover/" prefix routes to CoverArtProvider
                        source: model.hasCoverArt ? "image://musiccover/" + model.filePath : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: model.hasCoverArt
                        asynchronous: true       // Don't block UI thread while loading
                        sourceSize: Qt.size(200, 200)
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "?"; color: "#555"; font.pixelSize: 40
                        visible: !model.hasCoverArt   // Show when no art
                    }
                }

                Text { text: model.title;  color: "white"; elide: Text.ElideRight }
                Text { text: model.artist; color: "#aaa";  elide: Text.ElideRight }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        // contextCategory causes playTrackAtIndex to rebuild the queue
                        window.playTrackAtIndex(index, libraryView.activeCategoryName)
                    }
                }
            }
        }
    }
}
```

---

## 12.7 The Artist Grid — Circular Tiles

Artists use circular images (a design convention for artist portraits):

```qml
Rectangle {
    id: artArt
    radius: 100   // Large radius makes a square into a circle when width == height
    clip: true    // Clips the image to the circle
    Image {
        source: modelData.hasCoverArt ? "image://musiccover/" + modelData.filePath : ""
        fillMode: Image.PreserveAspectCrop
    }
}
```

Drill-down on artist click:
```qml
onClicked: {
    libraryView.activeCategoryName = modelData.name
    trackModel.filterByArtist(modelData.name)   // calls C++ TrackModel::filterByArtist
    mainStack.push(trackGridComponent)
}
```

---

## 12.8 `model` vs `modelData` Explained

Inside a delegate that uses a **C++ QAbstractListModel**, you access roles by name directly:
```qml
GridView {
    model: trackModel   // QAbstractListModel
    delegate: Text { text: model.title }   // or just: text: title
}
```

Inside a delegate that uses a **JavaScript array** (from `getAlbumTiles()` etc.), you access the current element via `modelData`:
```qml
GridView {
    model: trackModel.getAlbumTiles()   // Returns QVariantList → JS array
    delegate: Text { text: modelData.name }   // modelData = the current JS object
}
```

This distinction is a common source of confusion in QML.

---

## 12.9 Navigation Flow Summary

```
User selects "Artists" in sidebar
    → categoryContext = "Artists"
    → mainStack.push(artistGridComponent)
    → artistGridComponent.model = trackModel.getArtistTiles()

User clicks "Queen" tile
    → trackModel.filterByArtist("Queen")   (C++ model updates)
    → mainStack.push(trackGridComponent)
    → trackGridComponent.model = trackModel (now filtered to Queen only)

User clicks a song
    → window.playTrackAtIndex(index, "Queen")
    → Builds queue from current filtered model (only Queen songs)
    → audioEngine.loadFile() + audioEngine.play()

User clicks Back button
    → mainStack.pop()
    → Goes back to artistGridComponent
```
<div class="page-break"></div>
# Chapter 13 — EqualizerView.qml and NowPlayingView.qml

## 13.1 EqualizerView.qml

The Equalizer view is hosted in a `Popup` in `main.qml`. It provides:
- 10 vertical sliders (one per EQ band)
- Band frequency labels
- Gain readout per band (e.g., "+6 dB")
- An Enable/Disable toggle switch
- A preset combo box (loads factory + custom presets)
- Save/Delete custom preset controls

### Architecture

The EQ view communicates entirely through the `audioEngine.equalizer` object (a C++ `Equalizer*` exposed as `CONSTANT` Q_PROPERTY):

```qml
// EqualizerView.qml structure
Item {
    // Access the equalizer via the audioEngine context property
    property var eq: audioEngine.equalizer   // Shorthand alias

    // Enable switch
    Switch {
        checked: eq.enabled
        onToggled: eq.enabled = checked   // Calls Equalizer::setEnabled via Q_PROPERTY WRITE
    }

    // Preset selector
    ComboBox {
        id: presetBox
        model: eq.getPresetNames()    // Q_INVOKABLE — returns QStringList → JS array
        onActivated: eq.loadPreset(currentText)  // Q_INVOKABLE call directly from QML
    }

    // Save custom preset
    TextField {
        id: presetNameField
        placeholderText: "Save as..."
    }
    Button {
        text: "Save"
        onClicked: {
            if (presetNameField.text.length > 0) {
                eq.saveCustomPreset(presetNameField.text)  // Q_INVOKABLE
                presetBox.model = eq.getPresetNames()      // Refresh dropdown
            }
        }
    }

    // 10 band sliders (Repeater builds 10 columns)
    Repeater {
        model: 10    // 10 iterations
        delegate: Column {
            // Band label (31Hz, 62Hz, etc.)
            Text {
                text: {
                    var freq = eq.bandFrequency(index)   // Q_INVOKABLE
                    return freq >= 1000 ? (freq/1000).toFixed(0) + "k" : freq.toFixed(0)
                }
                color: "#aaa"
            }

            // Gain readout text (+6dB, -3dB, etc.)
            Text {
                text: {
                    var g = eq.bandGain(index)   // Q_INVOKABLE — reads current gain
                    return (g >= 0 ? "+" : "") + g.toFixed(1) + " dB"
                }
                color: "white"
            }

            // Vertical slider for this band
            Slider {
                orientation: Qt.Vertical
                from: -12.0; to: 12.0    // Signal range: -12dB to +12dB
                value: eq.bandGain(index) // Initial value from C++

                onMoved: {
                    eq.setBandGain(index, value)  // Public slot — triggers bandGainChanged signal
                    // bandGainChanged → AudioEngine::onEqualizerBandGainChanged
                    // → ma_peak_node_reinit → instant EQ change in audio pipeline
                }
            }
        }
    }
}
```

### Data Flow for Moving an EQ Slider

```
User drags slider for 1kHz band
         ↓
  Slider.onMoved fires in QML
         ↓
  eq.setBandGain(5, newValue) — calls Equalizer::setBandGain(5, newValue)
         ↓ (C++ Equalizer)
  m_gains[5] = clampedValue
  emit bandGainChanged(5, clampedValue)
         ↓ (signal-slot connection in AudioEngine constructor)
  AudioEngine::onEqualizerBandGainChanged(5, newValue)
         ↓
  ma_peak_node_reinit(&m_eqNodes[5], newConfig)
         ↓
  miniaudio applies new filter coefficients to the audio stream instantly
```

---

## 13.2 NowPlayingView.qml

This is a full-screen overlay (shown when you click the expand button in the playback bar). It provides a cinematic "Now Playing" experience:

```qml
// NowPlayingView.qml structure
Item {
    // Large blurred background using the album art
    Image {
        anchors.fill: parent
        source: window.currentPlayingPath !== "" ?
                "image://musiccover/" + window.currentPlayingPath : ""
        fillMode: Image.PreserveAspectCrop
        layer.enabled: true
        layer.effect: FastBlur { radius: 64 }   // Frosted glass blur effect
        opacity: 0.4
    }

    Column {
        // Large album art, centered
        Rectangle {
            width: 300; height: 300
            radius: 12
            Image {
                source: window.currentPlayingPath !== "" ?
                        "image://musiccover/" + window.currentPlayingPath : ""
                fillMode: Image.PreserveAspectCrop
            }
        }

        // Song title and artist
        Text { text: window.currentPlayingTitle;  font.pixelSize: 36; color: "white" }
        Text { text: window.currentPlayingArtist; font.pixelSize: 20; color: "#aaa" }

        // Progress slider
        Row {
            Text { text: formatTime(audioEngine.position); color: "white" }
            Slider {
                from: 0; to: audioEngine.duration
                value: audioEngine.position
                onMoved: audioEngine.position = value
            }
            Text { text: formatTime(audioEngine.duration); color: "white" }
        }

        // Playback controls (same as bottom bar)
        Row {
            RoundButton { onClicked: playTrackAtIndex(currentQueueIndex - 1) }
            RoundButton {
                icon.source: audioEngine.isPlaying ? "pause.svg" : "play.svg"
                onClicked: audioEngine.isPlaying ? audioEngine.pause() : audioEngine.play()
            }
            RoundButton { onClicked: playTrackAtIndex(currentQueueIndex + 1) }
        }

        // Repeat toggle
        ToolButton {
            icon.source: window.repeatMode ? "repeat_on.svg" : "repeat.svg"
            onClicked: window.repeatMode = !window.repeatMode
        }
    }
}
```

Key concept: `NowPlayingView` reads from `window.currentPlayingTitle`, `window.currentPlayingArtist`, and `window.currentPlayingPath` — all declared in `main.qml` (the root). Any child QML file can access the root by its `id: window`.

---

## 13.3 The `Connections` Pattern — Updating the EQ Sliders

When the user selects a preset like "Rock", `Equalizer::loadPreset("Rock")` calls `setBandGain(i, value)` for all 10 bands. Each call emits `bandGainChanged`. The QML sliders need to reflect these changes.

The cleanest way is to bind the slider `value` to `eq.bandGain(index)`:

```qml
Slider {
    value: eq.bandGain(index)   // This is a binding — updates whenever bandGain changes
    onMoved: eq.setBandGain(index, value)
}
```

BUT: When the user drags the slider, `value` changes and triggers `onMoved` → `setBandGain` → `bandGainChanged` → `value` tries to update again (circular). Qt handles this correctly — it only updates if the new value differs from the current, breaking the cycle.

---

## 13.4 Avoiding Binding Loops

A **binding loop** would be:
```qml
// DANGEROUS
width: parent.width   // width = parent.width
// Then somewhere else:
// parent.width: child.width ← circular!
```

Qt detects these at runtime and prints a warning. In the Equalizer, the pattern `value: eq.bandGain(index)` is safe because:
1. `onMoved` only fires when the **user** drags (not on programmatic value changes)
2. `setBandGain` only emits if the value actually changed (the `!=` check in C++)
<div class="page-break"></div>
# Chapter 14 — Complete System Dataflow

This chapter ties everything together with detailed data flow diagrams covering the three major user journeys.

---

## 14.1 Application Startup Flow

```
Program starts → main() runs
│
├─ [TagLib] Silence debug output
│
├─ [Qt] Set Material Dark theme env vars
│
├─ QApplication app constructed
│
├─ qmlRegisterUncreatableType<Equalizer>
│   → QML can now reference Equalizer* without creating instances
│
├─ AudioEngine audioEngine constructed
│   ├─ ma_engine_init() → opens system audio device (PulseAudio/WASAPI)
│   ├─ Equalizer *eq = new Equalizer(this)
│   ├─ 10 x ma_peak_node_init() → EQ filter chain created
│   ├─ ma_node_attach() × 10 → chain linked: sound→EQ0→EQ1→...→EQ9→speaker
│   └─ QTimer starts (250ms interval)
│
├─ LibraryScanner libraryScanner constructed
│   ├─ initializeDatabase() → opens/creates tracks.db SQLite file
│   └─ loadDatabase() → reads all rows, queues emit tracksAdded()
│
├─ TrackModel trackModel constructed
│
├─ connect(libraryScanner.tracksAdded → trackModel.setTracks)
│
├─ QQmlApplicationEngine engine constructed
│
├─ engine.addImageProvider("musiccover", new CoverArtProvider)
│
├─ engine.rootContext()->setContextProperty × 3
│   → "audioEngine", "libraryScanner", "trackModel" now in QML global scope
│
├─ engine.load("qrc:/qml/main.qml")
│   ├─ Qt parses main.qml, creates ApplicationWindow
│   ├─ ApplicationWindow creates LibraryView (embedded)
│   │   └─ LibraryView.StackView.initialItem = trackGridComponent
│   ├─ LibraryView trackGridComponent: model = trackModel (bound)
│   └─ QML engine completes
│
└─ app.exec() → Event loop begins
    │
    └─ QTimer fires (from loadDatabase's singleShot):
        tracksAdded(allTracks) → trackModel.setTracks(allTracks)
        → beginResetModel → endResetModel
        → LibraryView GridView refreshes (shows all cached tracks)
```

---

## 14.2 "Scan Directory" Flow

```
User: clicks hamburger menu → "Scan Directory"
│
├─ [QML] mainMenuPopup.close()
├─ [QML] folderDialog.open()
│
│  [User selects /home/user/music in the OS folder picker]
│
├─ [QML] folderDialog.onAccepted:
│       libraryScanner.scanDirectory(folderDialog.folder)
│                        ↓ (C++ slot called from QML)
│
├─ [C++] LibraryScanner::scanDirectory(path)
│   ├─ emit scanStarted()
│   │       ↓ [QML Connections.onScanStarted]
│   │       scanningPopup.open()  — shows spinner
│   │
│   └─ QtConcurrent::run([this, path]() {   // BACKGROUND THREAD
│           QDirIterator walks every subdir
│           │
│           For each .mp3/.flac/.wav/.m4a found:
│           │   TagLib::FileRef reads tags
│           │   Check cover art (format-specific code)
│           │   Build Track struct
│           │   newTracks.append(track)
│           │   filesProcessed++
│           │
│           │   if (filesProcessed % 10 == 0):
│           │       emit scanProgress(filesProcessed)
│           │               ↓ [QML Connections.onScanProgress]
│           │               scanningLabel.text = "Found N tracks..."
│           │
│           Write newTracks to tracks.db (SQLite transaction)
│           │
│           QMetaObject::invokeMethod(Qt::QueuedConnection):
│               → jumps back to main thread
│               loadDatabase()
│                   → reads all rows from DB
│                   → emit tracksAdded(allTracks)
│                           ↓ [connect in main.cpp]
│                   trackModel.setTracks(allTracks)
│                       beginResetModel
│                       sort by artist/album/disc/track
│                       rebuild displayIndices
│                       endResetModel
│                               ↓
│                   LibraryView GridView refreshes automatically
│               emit scanFinished(total)
│                       ↓ [QML Connections.onScanFinished]
│                   scanningPopup.close()
```

---

## 14.3 "Play a Song" Flow

```
User: clicks a track tile in LibraryView
│
├─ [QML] MouseArea.onClicked:
│       window.playTrackAtIndex(index, "All Tracks")
│
├─ [QML function] playTrackAtIndex(5, "All Tracks")
│   ├─ contextCategory is set → rebuild queue
│   │   for (i = 0..trackModel.rowCount()-1):
│   │       playbackQueue.push(trackModel.get(i))
│   │   currentQueueIndex = 5
│   │
│   ├─ var track = playbackQueue[5]
│   ├─ window.currentPlayingTitle  = track.title
│   ├─ window.currentPlayingArtist = track.artist
│   ├─ window.currentPlayingPath   = track.filePath
│   │       ↓ (all QML text bound to these auto-updates)
│   │
│   ├─ audioEngine.loadFile(track.filePath) — calls C++ slot
│   │       ↓ (AudioEngine::loadFile)
│   │       ma_sound_uninit (previous)
│   │       ma_sound_init_from_file (new file, ASYNC decode)
│   │       ma_node_attach(sound → eqNodes[0])
│   │       emit durationChanged(length)   → QML Slider.to updates
│   │       emit positionChanged(0)        → QML Slider.value resets
│   │
│   └─ audioEngine.play() — calls C++ slot
│           ↓ (AudioEngine::play)
│           ma_sound_start(&m_sound)
│           emit playingChanged(true)
│                   ↓ [Q_PROPERTY NOTIFY]
│           QML: audioEngine.isPlaying = true
│           Play/Pause button icon changes to "pause.svg"
│
│ [250ms timer fires repeatedly while playing]
│   AudioEngine timer callback:
│   ├─ ma_sound_at_end? → emit playbackFinished() → auto-advance
│   └─ isPlaying? → emit positionChanged(cursor)
│                           ↓ [Q_PROPERTY NOTIFY]
│               QML: Slider.value = audioEngine.position
│               QML: Time labels update
```

---

## 14.4 "Seek to Position" Flow

```
User: drags the progress slider to new position

[QML Slider.onMoved]
    audioEngine.position = value
         ↓ (Q_PROPERTY WRITE: calls setPosition)

[C++ AudioEngine::setPosition(newPos)]
    ma_engine_get_sample_rate → sampleRate
    targetFrame = newPos × sampleRate
    ma_sound_seek_to_pcm_frame(&m_sound, targetFrame)
    emit positionChanged(newPos)
         ↓ (Q_PROPERTY NOTIFY)
    [QML] Slider.value and time labels update to confirm the seek
```

---

## 14.5 "Change EQ Band" Flow

```
User: moves EQ slider for band 5 (1kHz)

[QML EqualizerView Slider.onMoved]
    eq.setBandGain(5, newValue)  — Q_INVOKABLE direct call
         ↓

[C++ Equalizer::setBandGain(5, newValue)]
    clampedValue = clamp(newValue, -12, 12)
    m_gains[5] = clampedValue
    emit bandGainChanged(5, clampedValue)
         ↓ (connect in AudioEngine constructor)

[C++ AudioEngine::onEqualizerBandGainChanged(5, clampedValue)]
    actualGain = eq->isEnabled() ? clampedValue : 0.0f
    ma_peak2_config cfg = ma_peak2_config_init(f32, ch, sr, actualGain, 1.414, 1000Hz)
    ma_peak_node_reinit(&m_eqNodes[5], &cfg)
         ↓
    Audio pipeline filter coefficients update instantly
    Users hears the frequency change in real time

[QML EqualizerView gain label]
    text: eq.bandGain(5)  → reads new value → shows "+3.0 dB"
    (updates because Slider.onMoved triggers re-read via binding)
```

---

## 14.6 Class Dependency Map

```
main.cpp
  ├── creates: AudioEngine
  │       owns: Equalizer (child QObject)
  │       uses: miniaudio (ma_engine, ma_sound, ma_peak_node[10])
  │       uses: QTimer (250ms heartbeat)
  │
  ├── creates: LibraryScanner
  │       uses: TagLib (reads tags)
  │       uses: QSqlDatabase (SQLite persistence)
  │       uses: QtConcurrent (background threads)
  │       uses: QDirIterator (filesystem walk)
  │
  ├── creates: TrackModel
  │       contains: QVector<Track> (all tracks in memory)
  │       contains: QVector<int> (display filter indices)
  │
  ├── connects: LibraryScanner.tracksAdded → TrackModel.setTracks
  │
  ├── exposes via setContextProperty:
  │       "audioEngine"    → AudioEngine*
  │       "libraryScanner" → LibraryScanner*
  │       "trackModel"     → TrackModel*
  │
  └── registers: CoverArtProvider under "musiccover"
                       uses: TagLib (reads embedded images)
                       uses: QImage (decodes JPEG/PNG bytes)
```
<div class="page-break"></div>
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

