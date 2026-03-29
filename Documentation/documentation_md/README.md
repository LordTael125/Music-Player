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
