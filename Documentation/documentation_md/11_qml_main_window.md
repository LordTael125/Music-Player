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
