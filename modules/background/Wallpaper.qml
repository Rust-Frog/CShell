pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import qs.components
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.config
import qs.utils

Item {
    id: root

    property string source: Wallpapers.current
    property string mediaType: Wallpapers.mediaType
    property Item current: one
    property bool completed

    // Video extensions for detection
    readonly property var videoExtensions: [".mp4", ".mkv", ".webm", ".avi", ".mov", ".m4v", ".flv"]

    function isVideo(path: string): bool {
        if (!path)
            return false;
        const lower = path.toLowerCase();
        return videoExtensions.some(ext => lower.endsWith(ext));
    }

    onSourceChanged: {
        if (!source) {
            current = null;
        } else if (current === one) {
            two.update();
        } else {
            one.update();
        }
    }

    Component.onCompleted: {
        if (source)
            Qt.callLater(() => {
                one.update();
                completed = true;
            });
    }

    // Missing wallpaper fallback UI
    Loader {
        asynchronous: true
        anchors.fill: parent

        active: root.completed && !root.source

        sourceComponent: StyledRect {
            color: Colours.palette.m3surfaceContainer

            Row {
                anchors.centerIn: parent
                spacing: Appearance.spacing.large

                MaterialIcon {
                    text: "sentiment_stressed"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.extraLarge * 5
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.spacing.small

                    StyledText {
                        text: qsTr("Wallpaper missing?")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.extraLarge * 2
                        font.bold: true
                    }

                    StyledRect {
                        implicitWidth: selectWallText.implicitWidth + Appearance.padding.large * 2
                        implicitHeight: selectWallText.implicitHeight + Appearance.padding.small * 2

                        radius: Appearance.rounding.full
                        color: Colours.palette.m3primary

                        FileDialog {
                            id: dialog

                            title: qsTr("Select a wallpaper")
                            filterLabel: qsTr("Image files")
                            filters: Images.validImageExtensions
                            onAccepted: path => Wallpapers.setWallpaper(path)
                        }

                        StateLayer {
                            function onClicked(): void {
                                dialog.open();
                            }

                            radius: parent.radius
                            color: Colours.palette.m3onPrimary
                        }

                        StyledText {
                            id: selectWallText

                            anchors.centerIn: parent

                            text: qsTr("Set it now!")
                            color: Colours.palette.m3onPrimary
                            font.pointSize: Appearance.font.size.large
                        }
                    }
                }
            }
        }
    }

    // Two wallpaper slots for crossfade transitions
    WallpaperSlot {
        id: one
    }

    WallpaperSlot {
        id: two
    }

    // Unified wallpaper slot that handles both images and videos
    component WallpaperSlot: Item {
        id: slot

        function update(): void {
            const newSource = root.source;
            const newIsVideo = root.isVideo(newSource);

            if (currentSource === newSource) {
                root.current = this;
                return;
            }

            currentSource = newSource;
            slotIsVideo = newIsVideo;

            if (newIsVideo) {
                imageLoader.active = false;
                videoLoader.active = true;
            } else {
                videoLoader.active = false;
                imageLoader.active = true;
            }
        }

        property string currentSource: ""

        property bool slotIsVideo: false

        property bool ready: slotIsVideo ? videoReady : imageReady

        property bool imageReady: imageLoader.item?.status === Image.Ready

        property bool videoReady: videoLoader.item?.ready ?? false

        anchors.fill: parent
        opacity: 0
        scale: Wallpapers.showPreview ? 1 : 0.8

        onReadyChanged: {
            if (ready)
                root.current = this;
        }

        states: State {
            name: "visible"
            when: root.current === slot

            PropertyChanges {
                slot.opacity: 1
                slot.scale: 1
            }
        }

        transitions: Transition {
            Anim {
                target: slot
                properties: "opacity,scale"
            }
        }

        // Image loader
        Loader {
            id: imageLoader

            anchors.fill: parent
            active: false
            asynchronous: true

            sourceComponent: CachingImage {
                path: slot.currentSource
            }
        }

        // Video loader
        Loader {
            id: videoLoader

            anchors.fill: parent
            active: false
            asynchronous: true

            sourceComponent: Item {
                id: videoItem

                property bool ready: player.playbackState === MediaPlayer.PlayingState

                MediaPlayer {
                    id: player

                    source: slot.currentSource ? `file://${slot.currentSource}` : ""
                    loops: MediaPlayer.Infinite
                    videoOutput: videoOutput
                    audioOutput: null  // Mute - wallpapers should be silent

                    onSourceChanged: {
                        if (source)
                            play();
                    }

                    Component.onCompleted: {
                        if (source)
                            play();
                    }
                }

                VideoOutput {
                    id: videoOutput

                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectCrop
                }
            }
        }
    }
}
