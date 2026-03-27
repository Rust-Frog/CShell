pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property bool enabled: Config.services.sunsetService?.manualEnabled ?? false
    property int temperature: Config.services.sunsetService?.temperature ?? 4500
    property int backend: backendWlGammarelay
    property bool backendDetected: false
    property string watchedBackend: Config.services.sunsetService?.preferredBackend ?? ""

    readonly property bool active: enabled
    readonly property int backendWlGammarelay: 0
    readonly property int backendHyprsunset: 1
    readonly property int backendWlsunset: 2
    readonly property int backendGammastep: 3

    function verifyBackend(name, command, targetBackend) {
        checkPreferredBackend.command = ["sh", "-c", command];
        checkPreferredBackend.targetBackend = targetBackend;
        checkPreferredBackend.running = true;
    }

    function detectBackend() {
        const preferredBackend = Config.services.sunsetService?.preferredBackend ?? "";
        if (preferredBackend !== undefined && preferredBackend !== "") {
            const backendMap = {
                "hyprsunset": [backendHyprsunset, "which hyprsunset >/dev/null 2>&1"],
                "wlsunset": [backendWlsunset, "which wlsunset >/dev/null 2>&1"],
                "gammastep": [backendGammastep, "which gammastep >/dev/null 2>&1"],
                "wl-gammarelay-rs": [backendWlGammarelay, "busctl --user status rs.wl-gammarelay >/dev/null 2>&1 || which wl-gammarelay-rs >/dev/null 2>&1"]
            };
            const backendData = backendMap[preferredBackend] || backendMap["wl-gammarelay-rs"];
            verifyBackend(preferredBackend, backendData[1], backendData[0]);
        } else {
            checkWlGammarelay.running = true;
        }
    }

    function updateWlGammarelay() {
        if (wlGammarelayProcess.running) {
            Quickshell.execDetached(["busctl", "--user", "set-property", "rs.wl-gammarelay", "/", "rs.wl.gammarelay", "Temperature", "q", temperature.toString()]);
        }
    }

    function restartProcess(process) {
        process.running = false;
        process.running = true;
    }

    onEnabledChanged: {
        if (Config.services.sunsetService) {
            Config.services.sunsetService.manualEnabled = enabled;
        }
    }

    onWatchedBackendChanged: {
        if (backendDetected) {
            detectBackend();
        }
    }

    onActiveChanged: {
        wlGammarelayProcess.running = false;
        sunsetProcess.running = false;
        wlsunsetProcess.running = false;
        gammastepProcess.running = false;
        killHyprsunset.running = true;
        killWlsunset.running = true;
        killGammastep.running = true;

        if (active) {
            switch (backend) {
            case backendWlGammarelay:
                wlGammarelayProcess.running = true;
                wlGammarelayInitTimer.start();
                break;
            case backendHyprsunset:
                updateTimer.restart();
                break;
            case backendWlsunset:
                updateWlsunsetTimer.restart();
                break;
            case backendGammastep:
                updateGammastepTimer.restart();
                break;
            }
        }
    }

    onTemperatureChanged: {
        if (Config.services.sunsetService && temperature !== (Config.services.sunsetService.temperature ?? 4500)) {
            Config.services.sunsetService.temperature = temperature;
        }

        if (active) {
            switch (backend) {
            case backendWlGammarelay:
                updateWlGammarelay();
                break;
            case backendHyprsunset:
                updateTimer.restart();
                break;
            case backendWlsunset:
                updateWlsunsetTimer.restart();
                break;
            case backendGammastep:
                updateGammastepTimer.restart();
                break;
            }
        }
    }

    Component.onCompleted: {
        Qt.callLater(detectBackend);
    }

    Process {
        id: checkPreferredBackend

        property int targetBackend: root.backendWlGammarelay

        onExited: (exitCode, exitStatus) => { // qmllint disable signal-handler-parameters
            if (exitCode === 0) {
                root.backend = targetBackend;
                root.backendDetected = true;
                if (root.active)
                    root.activeChanged();
            } else {
                console.warn("Preferred backend not found, falling back to auto-detection");
                checkWlGammarelay.running = true;
            }
        }
    }

    Process {
        id: checkWlGammarelay

        command: ["sh", "-c", "busctl --user status rs.wl-gammarelay >/dev/null 2>&1 || which wl-gammarelay-rs >/dev/null 2>&1"]

        onExited: (exitCode, exitStatus) => { // qmllint disable signal-handler-parameters
            if (exitCode === 0) {
                root.backend = root.backendWlGammarelay;
                root.backendDetected = true;
                if (root.active)
                    root.activeChanged();
            } else {
                checkGammastep.running = true;
            }
        }
    }

    Process {
        id: checkGammastep

        command: ["sh", "-c", "which gammastep >/dev/null 2>&1"]

        onExited: (exitCode, exitStatus) => { // qmllint disable signal-handler-parameters
            if (exitCode === 0) {
                root.backend = root.backendGammastep;
                root.backendDetected = true;
                if (root.active)
                    root.activeChanged();
            } else {
                checkWlsunset.running = true;
            }
        }
    }

    Process {
        id: checkWlsunset

        command: ["sh", "-c", "which wlsunset >/dev/null 2>&1"]

        onExited: (exitCode, exitStatus) => { // qmllint disable signal-handler-parameters
            if (exitCode === 0) {
                root.backend = root.backendWlsunset;
                root.backendDetected = true;
                if (root.active)
                    root.activeChanged();
            } else {
                checkHyprsunset.running = true;
            }
        }
    }

    Process {
        id: checkHyprsunset

        command: ["sh", "-c", "which hyprsunset >/dev/null 2>&1"]

        onExited: (exitCode, exitStatus) => { // qmllint disable signal-handler-parameters
            root.backend = root.backendHyprsunset;
            root.backendDetected = true;
            if (root.active)
                root.activeChanged();
        }
    }

    Process {
        id: wlGammarelayProcess

        command: ["wl-gammarelay-rs"]
    }

    Timer {
        id: wlGammarelayInitTimer

        interval: 300

        onTriggered: root.updateWlGammarelay()
    }

    Process {
        id: sunsetProcess

        command: ["hyprsunset", "-t", root.temperature.toString()]
    }

    Process {
        id: killHyprsunset

        command: ["pkill", "hyprsunset"]

        onExited: running = false // qmllint disable signal-handler-parameters
    }

    Timer {
        id: updateTimer

        interval: 300

        onTriggered: root.restartProcess(sunsetProcess)
    }

    Process {
        id: wlsunsetProcess

        command: ["wlsunset", "-T", "6500", "-t", root.temperature.toString(), "-S", "23:59", "-s", "00:00"]
    }

    Process {
        id: killWlsunset

        command: ["pkill", "wlsunset"]

        onExited: running = false // qmllint disable signal-handler-parameters
    }

    Timer {
        id: updateWlsunsetTimer

        interval: 300

        onTriggered: root.restartProcess(wlsunsetProcess)
    }

    Process {
        id: gammastepProcess

        command: ["gammastep", "-O", root.temperature.toString(), "-r"]
    }

    Process {
        id: killGammastep

        command: ["pkill", "gammastep"]

        onExited: running = false // qmllint disable signal-handler-parameters
    }

    Timer {
        id: updateGammastepTimer

        interval: 300

        onTriggered: root.restartProcess(gammastepProcess)
    }
}
