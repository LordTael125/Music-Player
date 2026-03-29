import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Item {
    id: libraryView
    property string activeCategoryName: "All Tracks"
    property string categoryContext: "All Tracks"
    property bool isSidebarVisible: false
    signal menuClicked()
    
    function goBack() {
        if (mainStack.depth > 1) {
            mainStack.pop()
            libraryView.activeCategoryName = libraryView.categoryContext
        }
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // Left sidebar for filters
        Rectangle {
            id: sidebarRect
            Layout.preferredWidth: isSidebarVisible ? 200 : 0
            Layout.fillHeight: true
            color: "#18181c"
            radius: 12
            clip: true
            visible: Layout.preferredWidth > 0

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
            }
            
            ColumnLayout {
                anchors.fill: parent
                
                Label {
                    text: "Filters"
                    font.pixelSize: 20
                    font.bold: true
                    color: "white"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 10
                    Layout.bottomMargin: 10
                }
                
                Repeater {
                    model: [
                        { name: "Tracks", ctx: "All Tracks" },
                        { name: "Artists", ctx: "Artists" },
                        { name: "Albums", ctx: "Albums" },
                        { name: "Folders", ctx: "Folders" },
                        { name: "Collections", ctx: "Collections" }
                    ]
                    
                    delegate: ItemDelegate {
                        Layout.fillWidth: true
                        height: 50
                        hoverEnabled: true

                        property bool isActive: libraryView.categoryContext === modelData.ctx

                        background: Rectangle {
                            color: parent.isActive ? "#2a2a35" : (parent.hovered ? "#22222b" : "transparent")
                            
                            // Left accent bar for active tab
                            Rectangle {
                                width: 4
                                height: parent.height
                                anchors.left: parent.left
                                color: "#0078d7" // Accent color
                                visible: parent.parent.isActive
                            }
                        }

                        contentItem: Text {
                            text: modelData.name
                            color: parent.isActive ? "white" : "#aaa"
                            font.pixelSize: 16
                            font.bold: parent.isActive
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 20
                        }

                        onClicked: {
                            libraryView.activeCategoryName = modelData.name === "Tracks" ? "All Tracks" : modelData.name
                            libraryView.categoryContext = modelData.ctx
                            if (modelData.name === "Tracks") trackModel.filterAll()
                            mainStack.clear()
                            
                            if (modelData.name === "Tracks") mainStack.push(trackGridComponent)
                            else if (modelData.name === "Artists") mainStack.push(artistGridComponent)
                            else if (modelData.name === "Albums") mainStack.push(albumGridComponent)
                            else if (modelData.name === "Folders") mainStack.push(folderGridComponent)
                            else if (modelData.name === "Collections") mainStack.push(collectionGridComponent)
                        }
                    }
                }
                Item { Layout.fillHeight: true } // spacer
            }
        }
        
        // Right side: Tile Grid view
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 15

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.topMargin: 5
                    spacing: 10

                    ToolButton {
                        icon.source: libraryView.isSidebarVisible ? "qrc:/qml/icons/panel_close.svg" : "qrc:/qml/icons/panel_open.svg"
                        icon.color: "white"
                        onClicked: libraryView.isSidebarVisible = !libraryView.isSidebarVisible
                    }

                    ToolButton {
                        visible: mainStack.depth > 1
                        icon.source: "qrc:/qml/icons/back.svg"
                        icon.color: "white"
                        onClicked: libraryView.goBack()
                    }

                    Label {
                        text: libraryView.activeCategoryName
                        font.pixelSize: 28
                        font.bold: true
                        color: "white"
                        Layout.fillWidth: true
                    }
                    
                    ToolButton {
                        icon.source: "qrc:/qml/icons/menu.svg"
                        icon.color: "white"
                        icon.width: 24
                        icon.height: 24
                        display: AbstractButton.IconOnly
                        onClicked: libraryView.menuClicked()
                    }
                }
                
                StackView {
                    id: mainStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    initialItem: trackGridComponent
                }
            }
        }
    }

    Component {
        id: trackGridComponent
        GridView {
            model: trackModel
            cellWidth: 160
            cellHeight: 200
            clip: true
            cacheBuffer: 1000
            
            delegate: Item {
                width: 160
                height: 200
                
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    color: window.currentPlayingPath === model.filePath ? "#2a2a35" : "#202025"
                    radius: 8
                    border.color: window.currentPlayingPath === model.filePath ? "#0078d7" : "transparent"
                    border.width: window.currentPlayingPath === model.filePath ? 2 : 0
                    
                    // Album Art
                    Rectangle {
                        id: artRect
                        width: parent.width - 20
                        height: width
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#33333b"
                        radius: 8
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: model.hasCoverArt ? "image://musiccover/" + model.filePath : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: model.hasCoverArt
                            asynchronous: true
                            sourceSize: Qt.size(200, 200)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "?"
                            color: "#555"
                            font.pixelSize: 40
                            visible: !model.hasCoverArt
                        }
                    }
                    
                    Text {
                        anchors.top: artRect.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: model.title
                        color: "white"
                        elide: Text.ElideRight
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: model.artist
                        color: "#aaa"
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            window.playTrackAtIndex(index, libraryView.activeCategoryName)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: albumGridComponent
        GridView {
            model: trackModel.getAlbumTiles()
            cellWidth: 180
            cellHeight: 220
            clip: true
            cacheBuffer: 1000
            delegate: Item {
                width: 180
                height: 220
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "#202025"
                    radius: 8
                    Rectangle {
                        id: albArt
                        width: parent.width - 20
                        height: width
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#33333b"
                        radius: 8
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: modelData.hasCoverArt ? "image://musiccover/" + modelData.filePath : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: modelData.hasCoverArt
                            asynchronous: true
                            sourceSize: Qt.size(200, 200)
                        }
                    }
                    Text {
                        anchors.top: albArt.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: modelData.name
                        color: "white"
                        elide: Text.ElideRight
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: modelData.artist
                        color: "#aaa"
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            libraryView.activeCategoryName = modelData.name
                            trackModel.filterByAlbum(modelData.name)
                            mainStack.push(trackGridComponent)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: artistGridComponent
        GridView {
            model: trackModel.getArtistTiles()
            cellWidth: 180
            cellHeight: 220
            clip: true
            cacheBuffer: 1000
            delegate: Item {
                width: 180
                height: 220
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "#202025"
                    radius: 8
                    Rectangle {
                        id: artArt
                        width: parent.width - 20
                        height: width
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#33333b"
                        radius: 100 // circle
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: modelData.hasCoverArt ? "image://musiccover/" + modelData.filePath : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: modelData.hasCoverArt
                            asynchronous: true
                            sourceSize: Qt.size(200, 200)
                        }
                    }
                    Text {
                        anchors.top: artArt.bottom
                        anchors.topMargin: 20
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: modelData.name
                        color: "white"
                        elide: Text.ElideRight
                        font.bold: true
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            libraryView.activeCategoryName = modelData.name
                            trackModel.filterByArtist(modelData.name)
                            mainStack.push(trackGridComponent)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: folderGridComponent
        GridView {
            model: trackModel.getFolderTiles()
            cellWidth: 180
            cellHeight: 220
            clip: true
            cacheBuffer: 1000
            delegate: Item {
                width: 180
                height: 220
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "#202025"
                    radius: 8
                    Rectangle {
                        id: folderArt
                        width: parent.width - 20
                        height: width
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#33333b"
                        radius: 8
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: modelData.hasCoverArt ? "image://musiccover/" + modelData.filePath : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: modelData.hasCoverArt
                            asynchronous: true
                            sourceSize: Qt.size(200, 200)
                        }
                    }
                    Text {
                        anchors.top: folderArt.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: modelData.name
                        color: "white"
                        elide: Text.ElideRight
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: "Directory"
                        color: "#aaa"
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            libraryView.activeCategoryName = modelData.name
                            trackModel.filterByFolder(modelData.path)
                            mainStack.push(trackGridComponent)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: collectionGridComponent
        GridView {
            model: trackModel.getCollectionTiles()
            cellWidth: 180
            cellHeight: 220
            clip: true
            cacheBuffer: 1000
            delegate: Item {
                width: 180
                height: 220
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "#202025"
                    radius: 8
                    Rectangle {
                        id: collectionArt
                        width: parent.width - 20
                        height: width
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "#33333b"
                        radius: 8
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: modelData.hasCoverArt ? "image://musiccover/" + modelData.filePath : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: modelData.hasCoverArt
                            asynchronous: true
                            sourceSize: Qt.size(200, 200)
                        }
                    }
                    Text {
                        anchors.top: collectionArt.bottom
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: modelData.name
                        color: "white"
                        elide: Text.ElideRight
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        text: "Collection"
                        color: "#aaa"
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            libraryView.activeCategoryName = modelData.name
                            trackModel.filterByCollection(modelData.name)
                            mainStack.push(trackGridComponent)
                        }
                    }
                }
            }
        }
    }
}
