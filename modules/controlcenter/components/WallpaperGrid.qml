pragma ComponentBehavior: Bound

import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Models
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.services
import qs.config

GridView {
    id: root

    required property Session session

    readonly property int minCellWidth: 200 + Appearance.spacing.normal
    readonly property int columnsCount: Math.max(1, Math.floor(width / minCellWidth))

    // Video file extensions
    readonly property var videoExtensions: [".mp4", ".mkv", ".webm", ".avi", ".mov", ".m4v", ".flv"]

    function isVideo(path: string): bool {
        const lower = path.toLowerCase();
        return videoExtensions.some(ext => lower.endsWith(ext));
    }

    cellWidth: width / columnsCount
    cellHeight: 140 + Appearance.spacing.normal

    model: Wallpapers.list

    Component.onCompleted: {}

    clip: true

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }

    delegate: Item {
        id: delegateItem

        required property var modelData
        required property int index
        readonly property bool isCurrent: modelData && modelData.path === Wallpapers.actualCurrent
        readonly property real itemMargin: Appearance.spacing.normal / 2
        readonly property real itemRadius: Appearance.rounding.normal
        readonly property bool isVideoFile: root.isVideo(modelData.path)

        width: root.cellWidth
        height: root.cellHeight

        // Generate video thumbnail on demand - use Timer to delay start
        Timer {
            id: thumbTimer

            interval: 100
            repeat: false
            onTriggered: {
                if (delegateItem.isVideoFile) {
                    delegateItem.shouldGenerateThumb = true;
                }
            }
        }

        Process {
            id: thumbnailProc

            command: ["caelestia", "wallpaper", "-T", delegateItem.modelData.path]
            running: delegateItem.shouldGenerateThumb && delegateItem.isVideoFile

            stdout: StdioCollector {
                onStreamFinished: {
                    delegateItem.thumbnailPath = text.trim();
                }
            }
        }

        property string thumbnailPath: ""

        property bool shouldGenerateThumb: false

        Component.onCompleted: {
            thumbTimer.running = true;
        }

        StateLayer {
            function onClicked(): void {
                Wallpapers.setWallpaper(modelData.path);
            }

            anchors.fill: parent
            anchors.leftMargin: itemMargin
            anchors.rightMargin: itemMargin
            anchors.topMargin: itemMargin
            anchors.bottomMargin: itemMargin
            radius: itemRadius
        }

        StyledClippingRect {
            id: image

            anchors.fill: parent
            anchors.leftMargin: itemMargin
            anchors.rightMargin: itemMargin
            anchors.topMargin: itemMargin
            anchors.bottomMargin: itemMargin
            color: Colours.tPalette.m3surfaceContainer
            radius: itemRadius
            antialiasing: true
            layer.enabled: true
            layer.smooth: true

            // For images: use regular Image with debug
            Image {
                id: cachingImage

                source: delegateItem.isVideoFile ? "" : "file://" + modelData.path
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                cache: true
                visible: !delegateItem.isVideoFile
                antialiasing: true
                smooth: true
                sourceSize: Qt.size(width, height)

                opacity: status === Image.Ready ? 1 : 0.3

                Behavior on opacity {
                    NumberAnimation {
                        duration: 1000
                        easing.type: Easing.OutQuad
                    }
                }
            }

            // For videos: use thumbnail from CLI
            Image {
                id: videoThumbnail

                anchors.fill: parent
                source: delegateItem.isVideoFile && delegateItem.thumbnailPath ? "file://" + delegateItem.thumbnailPath : ""
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                cache: true
                visible: delegateItem.isVideoFile
                antialiasing: true
                smooth: true
                sourceSize: Qt.size(width, height)

                opacity: status === Image.Ready ? 1 : 0.3

                Behavior on opacity {
                    NumberAnimation {
                        duration: 1000
                        easing.type: Easing.OutQuad
                    }
                }
            }

            // Fallback if CachingImage fails to load (images only)
            Image {
                id: fallbackImage

                anchors.fill: parent
                source: !delegateItem.isVideoFile && fallbackTimer.triggered && cachingImage.status !== Image.Ready ? modelData.path : ""
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                cache: true
                visible: opacity > 0
                antialiasing: true
                smooth: true
                sourceSize: Qt.size(width, height)

                opacity: status === Image.Ready && cachingImage.status !== Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 1000
                        easing.type: Easing.OutQuad
                    }
                }
            }

            Timer {
                id: fallbackTimer

                property bool triggered: false

                interval: 800
                running: !delegateItem.isVideoFile && (cachingImage.status === Image.Loading || cachingImage.status === Image.Null)
                onTriggered: triggered = true
            }

            // Gradient overlay for filename
            Rectangle {
                id: filenameOverlay

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                implicitHeight: filenameText.implicitHeight + Appearance.padding.normal * 1.5
                radius: 0

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(Colours.palette.m3surface.r, Colours.palette.m3surface.g, Colours.palette.m3surface.b, 0)
                    }
                    GradientStop {
                        position: 0.3
                        color: Qt.rgba(Colours.palette.m3surface.r, Colours.palette.m3surface.g, Colours.palette.m3surface.b, 0.7)
                    }
                    GradientStop {
                        position: 0.6
                        color: Qt.rgba(Colours.palette.m3surface.r, Colours.palette.m3surface.g, Colours.palette.m3surface.b, 0.9)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(Colours.palette.m3surface.r, Colours.palette.m3surface.g, Colours.palette.m3surface.b, 0.95)
                    }
                }

                opacity: 0

                Component.onCompleted: {
                    opacity = 1;
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 1000
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: itemMargin
            anchors.rightMargin: itemMargin
            anchors.topMargin: itemMargin
            anchors.bottomMargin: itemMargin
            color: "transparent"
            radius: itemRadius + border.width
            border.width: isCurrent ? 2 : 0
            border.color: Colours.palette.m3primary
            antialiasing: true
            smooth: true

            Behavior on border.width {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }

            // Video icon indicator
            MaterialIcon {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Appearance.padding.small

                visible: delegateItem.isVideoFile
                text: "play_circle"
                color: Colours.palette.m3onSurface
                font.pointSize: Appearance.font.size.large
            }

            MaterialIcon {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Appearance.padding.small

                visible: isCurrent
                text: "check_circle"
                color: Colours.palette.m3primary
                font.pointSize: Appearance.font.size.large
            }
        }

        StyledText {
            id: filenameText

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Appearance.padding.normal + Appearance.spacing.normal / 2
            anchors.rightMargin: Appearance.padding.normal + Appearance.spacing.normal / 2
            anchors.bottomMargin: Appearance.padding.normal

            text: modelData.name
            font.pointSize: Appearance.font.size.smaller
            font.weight: 500
            color: isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurface
            elide: Text.ElideMiddle
            maximumLineCount: 1
            horizontalAlignment: Text.AlignHCenter

            opacity: 0

            Component.onCompleted: {
                opacity = 1;
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 1000
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
