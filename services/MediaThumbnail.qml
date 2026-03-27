pragma Singleton

import QtQml
import Quickshell
import qs.services

Singleton {
    id: root

    property string thumbnailUrl: ""

    // YouTube thumbnail URL template
    readonly property string ytThumbTemplate: "https://img.youtube.com/vi/%1/maxresdefault.jpg"

    function extractYouTubeId(url: string): string {
        if (!url)
            return "";

        // Match various YouTube URL formats:
        // - https://www.youtube.com/watch?v=VIDEO_ID
        // - https://youtu.be/VIDEO_ID
        // - https://m.youtube.com/watch?v=VIDEO_ID
        const patterns = [
            /(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/,
            /youtube\.com\/embed\/([a-zA-Z0-9_-]{11})/,
            /youtube\.com\/v\/([a-zA-Z0-9_-]{11})/
        ];

        for (const pattern of patterns) {
            const match = url.match(pattern);
            if (match && match[1]) {
                return match[1];
            }
        }

        return "";
    }

    function updateThumbnail() {
        const active = Players.active;
        
        if (!active) {
            thumbnailUrl = "";
            return;
        }

        // If player already provides artwork, use it
        if (active.trackArtUrl && active.trackArtUrl !== "") {
            thumbnailUrl = active.trackArtUrl;
            return;
        }

        // Check if URL is from YouTube
        if (!active.metadata) {
            thumbnailUrl = "";
            return;
        }

        const trackUrl = active.metadata["xesam:url"] ?? "";
        const videoId = extractYouTubeId(trackUrl);

        if (videoId) {
            thumbnailUrl = ytThumbTemplate.arg(videoId);
        } else {
            thumbnailUrl = "";
        }
    }

    Connections {
        target: Players

        function onActiveChanged() {
            root.updateThumbnail();
        }
    }

    Connections {
        target: Players.active

        function onTrackChanged() {
            root.updateThumbnail();
        }

        function onTrackArtUrlChanged() {
            root.updateThumbnail();
        }
    }

    Component.onCompleted: {
        updateThumbnail();
    }
}
