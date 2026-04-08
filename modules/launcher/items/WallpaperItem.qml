import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Models
import qs.components
import qs.components.effects
import qs.components.images
import qs.services
import qs.config

Item {
    id: root

    required property FileSystemEntry modelData
    required property DrawerVisibilities visibilities

    scale: PathView.isCurrentItem ? 1 : (PathView.onPath ? 0.8 : 0)
    opacity: PathView.onPath ? 1 : 0
    z: PathView.z ?? 0

    readonly property var videoExtensions: [".mp4", ".mkv", ".webm", ".avi", ".mov", ".m4v", ".flv"]

    readonly property bool isVideo: {
        const lower = modelData.path.toLowerCase();
        return videoExtensions.some(ext => lower.endsWith(ext));
    }

    property string thumbPath: ""

    property bool generateThumb: false

    Component.onCompleted: {
        if (isVideo) {
            generateThumb = true;
        }
    }

    Process {
        command: ["caelestia", "wallpaper", "-T", root.modelData.path]
        running: root.generateThumb && root.isVideo

        stdout: StdioCollector {
            onStreamFinished: {
                root.thumbPath = text.trim();
            }
        }
    }

    implicitWidth: image.width + Appearance.padding.larger * 2

    implicitHeight: image.height + label.height + Appearance.spacing.small / 2 + Appearance.padding.large + Appearance.padding.normal

    StateLayer {
        function onClicked(): void {
            Wallpapers.setWallpaper(root.modelData.path);
            root.visibilities.launcher = false;
        }

        radius: Appearance.rounding.normal
    }

    Elevation {
        anchors.fill: image
        radius: image.radius
        opacity: root.PathView.isCurrentItem ? 1 : 0
        level: 4

        Behavior on opacity {
            Anim {}
        }
    }

    StyledClippingRect {
        id: image

        anchors.horizontalCenter: parent.horizontalCenter
        y: Appearance.padding.large
        color: Colours.tPalette.m3surfaceContainer
        radius: Appearance.rounding.normal

        implicitWidth: Config.launcher.sizes.wallpaperWidth
        implicitHeight: implicitWidth / 16 * 9

        // Only show icon for videos (as fallback when no thumbnail)
        MaterialIcon {
            anchors.centerIn: parent
            text: "play_circle"
            color: Colours.tPalette.m3outline
            font.pointSize: Appearance.font.size.extraLarge * 2
            font.weight: 600
            visible: isVideo && !thumbPath
        }

        Image {
            id: backgroundElement

            source: {
                if (isVideo)
                    return thumbPath ? "file://" + thumbPath : "";
                return "file://" + root.modelData.path;
            }
            smooth: !root.PathView.view.moving
            cache: true
            asynchronous: true
            fillMode: Image.PreserveAspectCrop

            anchors.fill: parent
        }
    }

    StyledText {
        id: label

        anchors.top: image.bottom
        anchors.topMargin: Appearance.spacing.small / 2
        anchors.horizontalCenter: parent.horizontalCenter

        width: image.width - Appearance.padding.normal * 2
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        renderType: Text.QtRendering
        text: root.modelData.relativePath
        font.pointSize: Appearance.font.size.normal
    }

    Behavior on scale {
        Anim {}
    }

    Behavior on opacity {
        Anim {}
    }
}
