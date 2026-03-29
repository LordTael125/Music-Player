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
