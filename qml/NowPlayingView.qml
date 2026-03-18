import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Layouts 1.15

Item {
    id: nowPlayingRoot

    // Format helper function
    function formatTime(seconds) {
        if (!seconds || isNaN(seconds)) return "00:00";
        let m = Math.floor(seconds / 60);
        let s = Math.floor(seconds % 60);
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    // Custom Title Bar for Now Playing (Matches main window)
    Rectangle {
        id: npTitleBar
        width: parent.width
        height: window.isFullScreen ? 0 : 35
        color: "transparent"
        visible: !window.isFullScreen
        z: 20

        DragHandler {
            onActiveChanged: if (active) window.startSystemMove()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 10
            spacing: 15

            Label {
                text: window.title + " - Now Playing"
                color: "white"
                font.bold: true
                font.pixelSize: 14
                Layout.fillWidth: true
            }

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
                        window.showNormal()
                    } else {
                        window.showMaximized()
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

    ToolButton {
        anchors.top: npTitleBar.bottom
        anchors.left: parent.left
        anchors.margins: 25
        icon.source: "qrc:/qml/icons/drop_down.svg"
        icon.color: "white"
        icon.width: 32
        icon.height: 32
        onClicked: nowPlayingPopup.close()
        display: AbstractButton.IconOnly
        z: 10
    }

    ToolButton {
        anchors.top: npTitleBar.bottom
        anchors.right: parent.right
        anchors.margins: 25
        icon.source: "qrc:/qml/icons/eq.svg"
        icon.color: "white"
        icon.width: 24
        icon.height: 24
        onClicked: eqPopup.open()
        display: AbstractButton.IconOnly
        z: 10
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 50

        // Large Album Art (Left Side)
        Rectangle {
            id: largeArt
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            Layout.preferredWidth: Math.min(parent.width * 0.55, 650)
            Layout.preferredHeight: width
            radius: 16
            color: "#202025"
            border.color: "#33333b"
            border.width: 1
            clip: true

            Image {
                anchors.fill: parent
                source: window.currentPlayingPath !== "" ? "image://musiccover/" + window.currentPlayingPath : ""
                fillMode: Image.PreserveAspectCrop
                visible: window.currentPlayingPath !== ""
                asynchronous: true
                sourceSize: Qt.size(600, 600)
            }

            Text {
                anchors.centerIn: parent
                text: "Album\nArt"
                color: "#555"
                font.pixelSize: 48
                horizontalAlignment: Text.AlignHCenter
                visible: window.currentPlayingPath === ""
            }
        }

        // Title and Artist and Controls (Right Side)
        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 15
            
            Item { Layout.fillHeight: true } // top spacer
            
            Text {
                text: window.currentPlayingTitle
                color: "white"
                font.pixelSize: 42
                font.bold: true
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Text {
                text: window.currentPlayingArtist
                color: "#aaa"
                font.pixelSize: 24
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Text {
                text: window.currentPlayingPath !== "" ? "Now Playing" : ""
                color: "#777"
                font.pixelSize: 20
            }
            
            Item { Layout.preferredHeight: 30 } // Visual separation
            
            // Re-adding Progress Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 15
                
                Text {
                    text: nowPlayingRoot.formatTime(audioEngine.position)
                    color: "#888"
                }
                
                Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: audioEngine.duration
                    value: audioEngine.position
                    onMoved: audioEngine.position = value
                }
                
                Text {
                    text: nowPlayingRoot.formatTime(audioEngine.duration)
                    color: "#888"
                }
            }
            
            // Playback Controls
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                RoundButton {
                    icon.source: window.repeatMode === 1 ? "qrc:/qml/icons/repeat_one.svg" : "qrc:/qml/icons/repeat.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    checked: window.repeatMode !== 0
                    onClicked: window.repeatMode = (window.repeatMode + 1) % 3
                    Material.background: window.repeatMode !== 0 ? Material.accent : "transparent"
                }
                
                RoundButton {
                    icon.source: "qrc:/qml/icons/prev.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    onClicked: {
                        if (audioEngine.position > 2.0) {
                            audioEngine.setPosition(0.0)
                        } else {
                            if (window.currentQueueIndex > 0) {
                                window.playTrackAtIndex(window.currentQueueIndex - 1)
                            }
                        }
                    }
                }
                
                RoundButton {
                    icon.source: audioEngine.isPlaying ? "qrc:/qml/icons/pause.svg" : "qrc:/qml/icons/play.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    width: 64
                    height: 64
                    onClicked: {
                        if (audioEngine.isPlaying) audioEngine.pause()
                        else audioEngine.play()
                    }
                }

                RoundButton {
                    icon.source: "qrc:/qml/icons/next.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    onClicked: {
                        if (window.currentQueueIndex >= 0 && window.currentQueueIndex < window.playbackQueue.length - 1) {
                            window.playTrackAtIndex(window.currentQueueIndex + 1)
                        }
                    }
                }

                RoundButton {
                    icon.source: "qrc:/qml/icons/stop.svg"
                    icon.color: "white"
                    display: AbstractButton.IconOnly
                    onClicked: audioEngine.stop()
                }
            }

            Item { Layout.fillHeight: true } // spacer
        }
    }

    RowLayout {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 35
        spacing: 20
        z: 10

        ToolButton {
            id: volumeButton
            icon.source: audioEngine.volume === 0.0 ? "qrc:/qml/icons/volume_off.svg" : "qrc:/qml/icons/volume.svg"
            icon.color: "white"
            display: AbstractButton.IconOnly
            width: 48
            height: 48
            onClicked: window.showVolumePopup(this)
        }

        ToolButton {
            icon.source: "qrc:/qml/icons/queue.svg"
            icon.color: "white"
            display: AbstractButton.IconOnly
            width: 48
            height: 48
            onClicked: queueDrawer.open()
        }
    }
}
