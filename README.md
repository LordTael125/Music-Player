<div align="center">
  
# 🎵 Modern Music Player

**A blazing-fast, lightweight, and gorgeous desktop music player built with C++ and Qt Quick.**

[![C++](https://img.shields.io/badge/C++-17-blue.svg)](https://isocpp.org/)
[![Qt](https://img.shields.io/badge/Qt-5.15-41cd52.svg)](https://www.qt.io/)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Docs](https://img.shields.io/badge/Developer%20Guide-available-brightgreen)](DEVELOPER_GUIDE.md)

</div>

<br/>

## 🌟 Overview

**Music Player** is a modern, high-performance local audio library manager tailored for users who want premium aesthetics without sacrificing system resources. Built from the ground up using **C++**, **Qt Quick (QML)**, and **MiniAudio**, it delivers a buttery-smooth 60 FPS experience even on heavily constrained hardware (e.g., dual-core CPUs with 500 MB of RAM).

Say goodbye to electron-bloat. Whether you have an organized library of 100 tracks or a sprawling, chaotic folder of 10,000 FLAC and MP3 files, Music Player handles it seamlessly via background QtConcurrent database threading and heavy memory-culling.

> 📖 **New contributor?** Read the complete [Developer Guide](DEVELOPER_GUIDE.md) for an in-depth walkthrough of the architecture, every C++ class, every QML view, and step-by-step build instructions.

---

## ✨ Key Features

### 🎨 Stunning Modern UI
- **Material Dark Design**: A beautifully curated dark aesthetic optimized for late-night listening.
- **Frameless Windowing**: Custom integrated window controls with click-and-drag borders.
- **Micro-Animations**: Fluid QML state transitions, hover effects, and queue displacement logic.
- **Dynamic Views**: Instantly pivot your library by **Tracks**, **Albums**, **Artists**, **Folders**, or **Collections**.

### ⚡ Extreme Performance & Low-Spec Optimization
- **Asynchronous Textures**: High-resolution album art (via `TagLib`) is extracted, heavily downscaled, and loaded strictly via hidden background worker threads. 
- **Zero-Lag Scrolling**: Scroll through thousands of album covers with absolutely zero UI block or stutter.
- **Background Library Scans**: Folder ingestion and SQLite metadata caching are decoupled via `QtConcurrent`, completely protecting the UI event loop from OS "Not Responding" freezes.
- **Tiny Footprint**: Entirely comfortably idles at under ~15-20 MB of RAM usage.

### 🎧 Powerful Audio Engine
- **MiniAudio Backend**: Utilizing the legendary `miniaudio.h` backend for flawless, cross-platform bit-perfect playback.
- **Built-in Equalizer**: Shape your sound exactly how you want it with an integrated EQ module.
- **Volume & Mute States**: Native cache memory preserves your volume configuration across application restarts and empty-queue states.

### ⌨️ Comprehensive Keyboard Shortcuts
Navigate your library at the speed of thought. Press **`?`** inside the app to pull up the dual-column Cheat Sheet.
- `Ctrl + P` : Toggle the Up Next Queue
- `Ctrl + M` : Mute / Unmute
- `Left` / `Right` : Seek -/+ 10 Seconds
- `Up` / `Down` : Volume Control
- `F` : Toggle Sidebar

---

## 🛠️ Technology Stack

- **Core Application**: [C++17](https://isocpp.org/)
- **GUI Framework**: [Qt 5.15 LTS (QML / Qt Quick)](https://www.qt.io/)
- **Audio Decoding**: [MiniAudio](https://miniaud.io/)
- **Metadata Tagging**: [TagLib](https://taglib.org/)
- **Database Caching**: [SQLite 3](https://www.sqlite.org/)

---

## 🚀 Building from Source

### Dependencies (Linux)
Ensure you have the following development packages installed (e.g., on Ubuntu / Debian / Manjaro):
- `cmake` & `make`
- `gcc` / `g++`
- Qt 5 development libraries (`qt5-base`, `qt5-quickcontrols2`, `qt5-svg`, `qt5-concurrent`)
- `taglib`

### Compilation
```bash
# Clone the repository
git clone https://github.com/LordTael125/Music-Player.git
cd Music-Player

# Generate build files
mkdir build && cd build
cmake ..

# Compile the application (utilizes all CPU cores)
cmake --build . -j$(nproc)

# Run the player!
./MusicPlayer
```

---

## 📜 License

This project is generously licensed under the **GNU General Public License v3.0 (GPLv3)**.  
You are free to use, modify, and distribute this software under the constraints of the license.

---

<div align="center">
  <i>Developed by <a href="https://github.com/LordTael125">LordTael125</a></i>
</div>
