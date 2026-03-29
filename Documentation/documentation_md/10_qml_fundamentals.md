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
