import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Window 2.15
import QtQuick.Layouts 1.15
import Qt.labs.platform 1.1 as Platform
import Qt.labs.settings 1.0
import QtGraphicalEffects 1.15

ApplicationWindow {
    id: window
    width: 1260
    height: 768
    visible: true
    visibility: Window.Maximized
    title: qsTr("Modern Music Player")
    flags: Qt.Window | Qt.FramelessWindowHint

    // Modern Dark Theme base
    Material.theme: Material.Dark
    Material.accent: Material.Purple
    color: "#0a0a0c" // Very deep almost black background

    // Global Now Playing State
    property string currentPlayingTitle: "No Song Playing"
    property string currentPlayingArtist: ""
    property string currentPlayingPath: ""
    property string applicationVersion: "1.1"
    property bool currentPlayingHasCoverArt: false
    property var playbackQueue: []
    property int currentQueueIndex: -1
    property int repeatMode: 0 // 0: Off, 1: Track, 2: All

    property bool isFullScreen: false
    function toggleFullScreen() {
        if (isFullScreen) {
            window.showMaximized();
            isFullScreen = false;
        } else {
            window.showFullScreen();
            isFullScreen = true;
        }
    }

    Settings {
        id: sessionSettings
        category: "MediaPlayer"
        property string savedQueue: "[]"
        property int savedQueueIndex: -1
        property real savedPosition: 0.0
        property int savedRepeatMode: 0
        property real savedVolume: 1.0
    }

    Timer {
        id: startupRestoreTimer
        interval: 200
        repeat: true
        running: true
        onTriggered: {
            if (trackModel.rowCount() > 0) {
                running = false;
                try {
                    audioEngine.volume = sessionSettings.savedVolume;
                    repeatMode = sessionSettings.savedRepeatMode;

                    let paths = JSON.parse(sessionSettings.savedQueue);
                    if (paths && paths.length > 0 && window.playbackQueue.length === 0) {
                        let newQueue = [];
                        for (let i = 0; i < paths.length; i++) {
                            // C++ getTrackByPath returns a QVariantMap which translates to a JS object
                            let track = trackModel.getTrackByPath(paths[i]);
                            // Ensure track is valid
                            if (track && track.filePath !== undefined && track.filePath !== "") {
                                newQueue.push(track);
                            }
                        }
                        if (newQueue.length > 0) {
                            window.playbackQueue = newQueue;
                            if (sessionSettings.savedQueueIndex >= 0 && sessionSettings.savedQueueIndex < newQueue.length) {
                                window.currentQueueIndex = sessionSettings.savedQueueIndex;
                                let t = window.playbackQueue[window.currentQueueIndex];
                                window.currentPlayingTitle = t.title;
                                window.currentPlayingArtist = t.artist;
                                window.currentPlayingPath = t.filePath;
                                window.currentPlayingHasCoverArt = t.hasCoverArt;

                                audioEngine.loadFile(t.filePath);
                                // Ensure miniaudio has enough time to initialize ASYNC load before seeking
                                restorePosTimer.start();
                            }
                        }
                    }
                } catch (e) {
                    console.log("Error restoring session:", e);
                }
            }
        }
    }

    Timer {
        id: restorePosTimer
        interval: 200
        onTriggered: {
            audioEngine.setPosition(sessionSettings.savedPosition);
        }
    }

    Component.onDestruction: {
        let paths = [];
        for (let i = 0; i < playbackQueue.length; i++) {
            paths.push(playbackQueue[i].filePath);
        }
        sessionSettings.savedQueue = JSON.stringify(paths);
        sessionSettings.savedQueueIndex = currentQueueIndex;
        sessionSettings.savedPosition = audioEngine.position;
        sessionSettings.savedVolume = audioEngine.volume;
        sessionSettings.savedRepeatMode = repeatMode;
    }

    function playTrackAtIndex(idx, contextCategory) {
        if (idx < 0)
            return;

        // If an external category is passed, repopulate the queue
        if (contextCategory) {
            let newQueue = [];
            // Push everything from current visible model into the queue so users can skip forward
            for (var i = 0; i < trackModel.rowCount(); i++) {
                newQueue.push(trackModel.get(i));
            }
            playbackQueue = newQueue;
            currentQueueIndex = idx;
        } else {
            // Internal call (Next/Prev from Queue)
            currentQueueIndex = idx;
        }

        if (currentQueueIndex < 0 || currentQueueIndex >= playbackQueue.length)
            return;

        var track = playbackQueue[currentQueueIndex];
        if (!track)
            return;

        currentPlayingTitle = track.title;
        currentPlayingArtist = track.artist;
        currentPlayingPath = track.filePath;
        currentPlayingHasCoverArt = track.hasCoverArt;

        audioEngine.loadFile(track.filePath);
        audioEngine.play();
    }

    function showVolumePopup(callerItem) {
        var pos = callerItem.mapToItem(window.contentItem, 0, 0);
        volumePopup.x = Math.max(0, Math.round(pos.x + callerItem.width / 2 - volumePopup.width / 2));
        volumePopup.y = Math.max(0, Math.round(pos.y - volumePopup.height - 25)); // Added negative offset to hover
        volumePopup.open();
    }

    Connections {
        target: audioEngine
        function onPlaybackFinished() {
            if (repeatMode === 1) { // Repeat Track
                audioEngine.setPosition(0);
                audioEngine.play();
            } else if (repeatMode === 2) { // Repeat All
                if (currentQueueIndex >= 0 && currentQueueIndex < playbackQueue.length - 1) {
                    playTrackAtIndex(currentQueueIndex + 1);
                } else if (playbackQueue.length > 0) {
                    playTrackAtIndex(0); // Loop back
                }
            } else { // Repeat Off
                if (currentQueueIndex >= 0 && currentQueueIndex < playbackQueue.length - 1) {
                    playTrackAtIndex(currentQueueIndex + 1);
                }
            }
        }
    }

    Platform.FolderDialog {
        id: folderDialog
        title: "Please choose a folder with Music"
        onAccepted: {
            libraryScanner.scanDirectory(folderDialog.folder);
        }
    }

    // --- Global Keyboard Shortcuts ---
    property real previousVolume: 1.0

    Shortcut {
        sequence: "Ctrl+Left"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (audioEngine.position > 2.0) {
                audioEngine.setPosition(0.0);
            } else {
                if (window.currentQueueIndex > 0) {
                    playTrackAtIndex(window.currentQueueIndex - 1);
                }
            }
        }
    }
    Shortcut {
        sequence: "Ctrl+Right"
        context: Qt.ApplicationShortcut
        onActivated: playTrackAtIndex(currentQueueIndex + 1)
    }
    Shortcut {
        sequence: "Backspace"
        context: Qt.ApplicationShortcut
        onActivated: libraryViewMain.goBack()
    }
    Shortcut {
        sequence: StandardKey.Back
        context: Qt.ApplicationShortcut
        onActivated: libraryViewMain.goBack()
    }
    Shortcut {
        sequence: "Ctrl+Shift+F"
        context: Qt.ApplicationShortcut
        onActivated: toggleFullScreen()
    }
    Shortcut {
        sequence: "Space"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (audioEngine.isPlaying)
                audioEngine.pause();
            else
                audioEngine.play();
        }
    }
    Shortcut {
        sequence: "Ctrl+M"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (audioEngine.volume > 0.01) {
                previousVolume = audioEngine.volume;
                audioEngine.volume = 0.0;
            } else {
                audioEngine.volume = previousVolume > 0.01 ? previousVolume : 1.0;
            }
        }
    }
    Shortcut {
        sequence: "Left"
        context: Qt.ApplicationShortcut
        onActivated: audioEngine.setPosition(audioEngine.position - 10.0)
    }
    Shortcut {
        sequence: "Right"
        context: Qt.ApplicationShortcut
        onActivated: audioEngine.setPosition(audioEngine.position + 10.0)
    }
    Shortcut {
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: audioEngine.volume = Math.min(1.0, audioEngine.volume + 0.1)
    }
    Shortcut {
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: audioEngine.volume = Math.max(0.0, audioEngine.volume - 0.1)
    }
    Shortcut {
        sequence: "Ctrl+P"
        context: Qt.ApplicationShortcut
        onActivated: queueDrawer.visible = !queueDrawer.visible
    }
    Shortcut {
        sequence: "F"
        context: Qt.ApplicationShortcut
        onActivated: libraryViewMain.isSidebarVisible = !libraryViewMain.isSidebarVisible
    }
    Shortcut {
        sequence: "Ctrl+Q"
        context: Qt.ApplicationShortcut
        onActivated: Qt.quit()
    }
    // Esc is naturally handled by Qt Popups to close them, so no explicit mapping needed here.

    // Header removed per blueprint. Menu button is now floating.

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Custom Title Bar
        Rectangle {
            id: titleBar
            Layout.fillWidth: true
            Layout.preferredHeight: window.isFullScreen ? 0 : 35
            color: "transparent"
            visible: !window.isFullScreen

            // Drag Handler for moving the frameless window
            DragHandler {
                onActiveChanged: if (active)
                    window.startSystemMove()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 10
                spacing: 15

                Label {
                    text: window.title
                    color: "white"
                    font.bold: true
                    font.pixelSize: 14
                }

                Item {
                    Layout.fillWidth: true
                } // spacer pushes buttons to the right

                ToolButton {
                    icon.source: "qrc:/qml/icons/minimize.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    onClicked: window.showMinimized()
                }

                ToolButton {
                    icon.source: "qrc:/qml/icons/maximize.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    onClicked: {
                        if (window.visibility === Window.Maximized) {
                            window.showNormal();
                        } else {
                            window.showMaximized();
                        }
                    }
                }

                ToolButton {
                    icon.source: "qrc:/qml/icons/close.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    onClicked: window.close()
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            LibraryView {
                id: libraryViewMain
                anchors.fill: parent
                onMenuClicked: mainMenuPopup.open()
            }
        }

        Popup {
            id: mainMenuPopup
            x: window.width - width - 15
            y: 45
            width: 220
            padding: 5
            background: Rectangle {
                color: "#18181c"
                border.color: "#33333b"
                radius: 8
            }
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            ColumnLayout {
                anchors.fill: parent
                spacing: 2

                Button {
                    Layout.fillWidth: true
                    text: "Toggle Fullscreen"
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 15
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 15
                        topPadding: 8
                        bottomPadding: 8
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#2a2a35" : "transparent"
                        radius: 4
                    }
                    onClicked: {
                        mainMenuPopup.close();
                        toggleFullScreen();
                    }
                }
                Button {
                    Layout.fillWidth: true
                    text: "Scan Directory"
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 15
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 15
                        topPadding: 8
                        bottomPadding: 8
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#2a2a35" : "transparent"
                        radius: 4
                    }
                    onClicked: {
                        mainMenuPopup.close();
                        folderDialog.open();
                    }
                }
                Button {
                    Layout.fillWidth: true
                    text: "Clear Database"
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 15
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 15
                        topPadding: 8
                        bottomPadding: 8
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#2a2a35" : "transparent"
                        radius: 4
                    }
                    onClicked: {
                        mainMenuPopup.close();
                        libraryScanner.clearDatabase();
                        window.playbackQueue = [];
                        window.currentQueueIndex = -1;
                        window.currentPlayingTitle = "No Song Playing";
                        window.currentPlayingArtist = "";
                        window.currentPlayingPath = "";
                        audioEngine.stop();
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#33333b"
                }
                Button {
                    Layout.fillWidth: true
                    text: "Keyboard Shortcuts"
                    contentItem: Text {
                        text: parent.text
                        color: "#0078d7"
                        font.bold: true
                        font.pixelSize: 15
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 15
                        topPadding: 8
                        bottomPadding: 8
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#2a2a35" : "transparent"
                        radius: 4
                    }
                    onClicked: {
                        mainMenuPopup.close();
                        shortcutsPopup.open();
                    }
                }
                Button {
                    Layout.fillWidth: true
                    text: "About Music Player"
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 15
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 15
                        topPadding: 8
                        bottomPadding: 8
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#2a2a35" : "transparent"
                        radius: 4
                    }
                    onClicked: {
                        mainMenuPopup.close();
                        supportPopup.open();
                    }
                }
            }
        }

        // Equalizer Popup
        Popup {
            id: eqPopup
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            width: Math.min(window.width * 0.9, 850)
            height: Math.min(window.height * 0.8, 650)
            modal: true
            focus: true
            padding: 0
            background: Rectangle {
                color: "#18181c"
                radius: 12
                border.color: "#33333b"
                border.width: 1
            }
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            EqualizerView {
                anchors.fill: parent
            }
        }

        // Volume Popup
        Popup {
            id: volumePopup
            width: 60
            height: 200
            padding: 10
            background: Rectangle {
                color: "#18181c"
                radius: 12
                border.color: "#33333b"
                border.width: 1
            }
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            Slider {
                anchors.centerIn: parent
                height: 160
                orientation: Qt.Vertical
                from: 0.0
                to: 1.0
                value: audioEngine.volume
                onMoved: audioEngine.volume = value
            }
        }

        // Now Playing Popup Overlay
        Popup {
            id: nowPlayingPopup
            x: 0
            y: 0
            width: parent.width
            height: parent.height
            modal: false
            focus: true
            padding: 0
            background: Rectangle {
                color: "#0a0a0c"
            }
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            NowPlayingView {
                anchors.fill: parent
            }
        }

        // Keyboard Shortcuts Popup
        Popup {
            id: shortcutsPopup
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            width: 750
            height: 480
            modal: true
            focus: true
            background: Rectangle {
                color: "#18181c"
                radius: 12
                border.color: "#33333b"
                border.width: 1
            }
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 25
                spacing: 12

                Label {
                    text: "Keyboard Shortcuts"
                    font.bold: true
                    font.pixelSize: 20
                    color: "white"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 10
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#33333b"
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 30
                    rowSpacing: 15

                    Repeater {
                        model: [
                            {
                                k: "Space",
                                d: "Play / Pause"
                            },
                            {
                                k: "Ctrl + Left",
                                d: "Play Previous Track"
                            },
                            {
                                k: "Ctrl + Right",
                                d: "Play Next Track"
                            },
                            {
                                k: "Left / Right",
                                d: "Seek +/- 10 Seconds"
                            },
                            {
                                k: "Up / Down",
                                d: "Volume +/- 10%"
                            },
                            {
                                k: "Ctrl + M",
                                d: "Mute / Unmute"
                            },
                            {
                                k: "Ctrl + P",
                                d: "Toggle Queue Panel"
                            },
                            {
                                k: "F",
                                d: "Toggle Library Filters"
                            },
                            {
                                k: "Ctrl+Shift+F",
                                d: "Toggle Fullscreen"
                            },
                            {
                                k: "Backspace",
                                d: "Go Back (Library)"
                            },
                            {
                                k: "Esc",
                                d: "Close Menus / Popups"
                            },
                            {
                                k: "Ctrl + Q",
                                d: "Quit Player"
                            }
                        ]

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            color: "transparent"
                            radius: 4

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                Rectangle {
                                    Layout.preferredWidth: 110
                                    Layout.preferredHeight: 24
                                    color: "#22222b"
                                    radius: 4
                                    border.color: "#33333b"

                                    Label {
                                        anchors.centerIn: parent
                                        text: modelData.k
                                        color: "#0078d7"
                                        font.bold: true
                                        font.pixelSize: 13
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: 10
                                } // Spacer

                                Label {
                                    text: modelData.d
                                    color: "#e0e0e0"
                                    font.pixelSize: 14
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                Button {
                    text: "Got It"
                    Layout.alignment: Qt.AlignHCenter
                    background: Rectangle {
                        color: "#0078d7"
                        radius: 6
                        implicitWidth: 100
                        implicitHeight: 35
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.bold: true
                    }
                    onClicked: shortcutsPopup.close()
                }
            }
        }

        // Support / About Popup
        Popup {
            id: supportPopup
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            width: 380
            height: 320
            modal: true
            focus: true
            background: Rectangle {
                color: "#18181c"
                radius: 12
                border.color: "#33333b"
                border.width: 1
            }
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 25
                spacing: 15

                Label {
                    text: "Modern Music Player"
                    font.bold: true
                    font.pixelSize: 22
                    color: "white"
                    Layout.alignment: Qt.AlignHCenter
                }

                Label {
                    text: "Version " + applicationVersion
                    font.pixelSize: 14
                    color: "#aaa"
                    Layout.alignment: Qt.AlignHCenter
                }

                Label {
                    text: "Built with Qt C++"
                    font.pixelSize: 14
                    color: "#aaa"
                    Layout.alignment: Qt.AlignHCenter
                }

                Label {
                    text: "Covered under <a href='https://www.gnu.org/licenses/gpl-3.0.html'>GPLv3 License</a>"
                    font.pixelSize: 14
                    color: "white"
                    linkColor: "#0078d7"
                    Layout.alignment: Qt.AlignHCenter
                    onLinkActivated: Qt.openUrlExternally(link)
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#33333b"
                }

                Label {
                    text: "Developed by <a href='https://github.com/LordTael125'>LordTael125</a>"
                    font.pixelSize: 16
                    color: "white"
                    linkColor: "#0078d7"
                    Layout.alignment: Qt.AlignHCenter
                    onLinkActivated: Qt.openUrlExternally(link)
                }

                Item {
                    Layout.fillHeight: true
                }

                Button {
                    text: "Close"
                    Layout.alignment: Qt.AlignHCenter
                    background: Rectangle {
                        color: "#33333b"
                        radius: 6
                        implicitWidth: 100
                        implicitHeight: 35
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.bold: true
                    }
                    onClicked: supportPopup.close()
                }
            }
        }

        // Scanning Progress Popup
        Popup {
            id: scanningPopup
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            width: 350
            height: 180
            modal: true
            focus: true
            closePolicy: Popup.NoAutoClose
            background: Rectangle {
                color: "#18181c"
                radius: 12
                border.color: "#33333b"
                border.width: 1
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20

                BusyIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    running: scanningPopup.visible
                }

                Label {
                    id: scanningLabel
                    text: "Scanning Library..."
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        Connections {
            target: libraryScanner
            function onScanStarted() {
                scanningPopup.open();
                scanningLabel.text = "Scanning Library... Please Wait";
            }
            function onScanProgress(count) {
                scanningLabel.text = "Found " + count + " Tracks...";
            }
            function onScanFinished(total) {
                scanningPopup.close();
            }
        }

        // Queue Drawer
        Drawer {
            id: queueDrawer
            edge: Qt.RightEdge
            width: Math.min(window.width * 0.4, 400)
            height: parent.height
            background: Rectangle {
                color: "#18181c"
                border.color: "#33333b"
                border.width: 1
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15

                Label {
                    text: "Up Next"
                    font.pixelSize: 24
                    font.bold: true
                    color: "white"
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: window.playbackQueue
                    cacheBuffer: 1000

                    add: Transition {
                        NumberAnimation {
                            properties: "y"
                            duration: 250
                            easing.type: Easing.OutQuad
                        }
                    }
                    displaced: Transition {
                        NumberAnimation {
                            properties: "y"
                            duration: 250
                            easing.type: Easing.OutQuad
                        }
                    }
                    remove: Transition {
                        NumberAnimation {
                            properties: "y"
                            duration: 250
                            easing.type: Easing.OutQuad
                        }
                    }

                    delegate: ItemDelegate {
                        width: ListView.view.width

                        property bool isVisibleItem: index >= window.currentQueueIndex

                        height: isVisibleItem ? 60 : 0
                        opacity: isVisibleItem ? 1.0 : 0.0
                        visible: height > 0 || opacity > 0

                        Behavior on height {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 250
                            }
                        }

                        // Highlight current playing song
                        background: Rectangle {
                            color: index === window.currentQueueIndex ? "#2a2a35" : (parent.hovered ? "#22222b" : "transparent")
                            radius: 6

                            Behavior on color {
                                ColorAnimation {
                                    duration: 250
                                }
                            }

                            Rectangle {
                                width: 4
                                height: parent.height
                                anchors.left: parent.left
                                color: "#0078d7"
                                visible: index === window.currentQueueIndex
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 15

                            Image {
                                source: modelData.hasCoverArt ? "image://musiccover/" + modelData.filePath : "qrc:/qml/icons/play.svg"
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(100, 100)
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.title
                                    color: "white"
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.artist
                                    color: "#aaa"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        onClicked: {
                            window.playTrackAtIndex(index);
                        }
                    }
                }
            }
        }

        // Persistent Bottom Playback Bar
        Rectangle {
            id: playbackBar
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            color: "#18181c"
            border.color: "#33333b"
            border.width: 1
            radius: 10

            // Format helper function
            function formatTime(seconds) {
                if (!seconds || isNaN(seconds))
                    return "00:00";
                let m = Math.floor(seconds / 60);
                let s = Math.floor(seconds % 60);
                return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
            }

            Item {
                anchors.fill: parent
                anchors.margins: 1

                // Section 1: Left Container (Art + Track Info)
                Item {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: centerContainer.left
                    clip: true

                    RowLayout {
                        anchors.fill: parent
                        spacing: 20

                        Item {
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 80
                            Layout.leftMargin: 25

                            Image {
                                id: coverArtImage
                                source: nowPlayingPopup.opened ? "qrc:/qml/icons/expand_down.svg" : (window.currentPlayingHasCoverArt ? "image://musiccover/" + window.currentPlayingPath : "qrc:/qml/icons/play.svg")
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(160, 160)
                                anchors.fill: parent
                                visible: false
                            }

                            Rectangle {
                                id: coverMask
                                anchors.fill: parent
                                radius: 8
                                visible: false
                            }

                            OpacityMask {
                                anchors.fill: coverArtImage
                                source: coverArtImage
                                maskSource: coverMask
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (nowPlayingPopup.opened)
                                        nowPlayingPopup.close();
                                    else
                                        nowPlayingPopup.open();
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Text {
                                text: window.currentPlayingTitle
                                color: "#d9edfd"
                                font.pixelSize: 18
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: window.currentPlayingArtist
                                color: "#aaa"
                                font.pixelSize: 14
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                // Section 2: Center Container (Playback Controls)
                ColumnLayout {
                    id: centerContainer
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 0
                    width: Math.max(300, Math.min(600, parent.width - 400))

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: 40
                        spacing: 20

                        ToolButton {
                            icon.source: "qrc:/qml/icons/prev.svg"
                            icon.color: "white"
                            display: AbstractButton.IconOnly
                            width: 40
                            height: 40
                            onClicked: {
                                if (audioEngine.position > 2.0) {
                                    audioEngine.setPosition(0.0);
                                } else {
                                    if (window.currentQueueIndex > 0) {
                                        window.playTrackAtIndex(window.currentQueueIndex - 1);
                                    } else
                                        audioEngine.setPosition(0.0);
                                }
                            }
                        }

                        ToolButton {
                            icon.source: audioEngine.isPlaying ? "qrc:/qml/icons/pause.svg" : "qrc:/qml/icons/play.svg"
                            icon.color: "white"
                            display: AbstractButton.IconOnly
                            width: 40
                            height: 40
                            onClicked: {
                                if (window.currentQueueIndex === -1 && window.playbackQueue.length > 0) {
                                    window.playTrackAtIndex(0);
                                } else {
                                    if (audioEngine.isPlaying)
                                        audioEngine.pause();
                                    else
                                        audioEngine.play();
                                }
                            }
                        }

                        ToolButton {
                            icon.source: "qrc:/qml/icons/next.svg"
                            icon.color: "white"
                            display: AbstractButton.IconOnly
                            width: 40
                            height: 40
                            onClicked: {
                                if (window.currentQueueIndex >= 0 && window.currentQueueIndex < window.playbackQueue.length - 1) {
                                    window.playTrackAtIndex(window.currentQueueIndex + 1);
                                }
                            }
                        }

                        ToolButton {
                            icon.source: window.repeatMode === 1 ? "qrc:/qml/icons/repeat_one.svg" : "qrc:/qml/icons/repeat.svg"
                            icon.color: window.repeatMode !== 0 ? Material.color(Material.Purple) : "white"
                            display: AbstractButton.IconOnly
                            width: 40
                            height: 40
                            onClicked: window.repeatMode = (window.repeatMode + 1) % 3
                        }
                    }

                    RowLayout {
                        Layout.preferredWidth: 200
                        Layout.fillWidth: true
                        Layout.topMargin: -10
                        spacing: 15

                        Text {
                            text: playbackBar.formatTime(audioEngine.position)
                            color: "white"
                            font.pixelSize: 12
                        }

                        Slider {
                            Layout.fillWidth: true
                            from: 0
                            to: audioEngine.duration
                            value: audioEngine.position
                            onMoved: audioEngine.position = value
                        }

                        Text {
                            text: playbackBar.formatTime(audioEngine.duration)
                            color: "white"
                            font.pixelSize: 12
                        }
                    }
                }

                // Section 3: Right Container (Tools)
                Item {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: centerContainer.right
                    clip: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.rightMargin: 40
                        spacing: 15

                        Item {
                            Layout.fillWidth: true
                        } // Pushes tools to the right edge

                        ToolButton {
                            icon.source: audioEngine.volume <= 0.01 ? "qrc:/qml/icons/volume_off.svg" : "qrc:/qml/icons/volume.svg"
                            icon.color: "white"
                            display: AbstractButton.IconOnly
                            width: 35
                            height: 35
                            onClicked: window.showVolumePopup(this)
                        }

                        ToolButton {
                            icon.source: "qrc:/qml/icons/eq.svg"
                            icon.color: "white"
                            display: AbstractButton.IconOnly
                            width: 35
                            height: 35
                            onClicked: eqPopup.open()
                        }

                        ToolButton {
                            icon.source: "qrc:/qml/icons/queue.svg"
                            icon.color: "white"
                            display: AbstractButton.IconOnly
                            width: 40
                            height: 40
                            onClicked: queueDrawer.open()
                        }
                    }
                }
            }
        }
    }
}
