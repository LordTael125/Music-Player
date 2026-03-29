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
