pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool enabled: Config.services.nightColor ?? false
    property bool available: false
    property int temperature: Config.services.nightColorTemp ?? 4500
    property int _activeTemp: temperature
    property bool _pendingTempUpdate: false

    function setEnabled(val: bool): void {
        enabled = val;
        Config.services.nightColor = val;
        Config.save();
        if (val && available) {
            _activeTemp = temperature;
            _start();
        } else if (!val) {
            _stop();
        }
    }

    function setTemperature(val: int): void {
        temperature = val;
        _activeTemp = val;
        Config.services.nightColorTemp = val;
        Config.save();
        if (enabled && available) {
            if (hyprsunsetProc.running) {
                _applyTemp();  // already running (drag while enabled), just ensure final temp is applied
            } else {
                _start();  // wasn't running for some reason, start fresh
            }
        } else {
            _stop();  // disabled: kill preview, screen back to normal
        }
    }

    // Called on every slider tick — starts hyprsunset on first call, updates via hyprctl on subsequent
    function startPreview(temp: int): void {
        if (!available) return;
        _activeTemp = temp;
        if (!hyprsunsetProc.running) {
            _start();  // first press: start hyprsunset (one fade-in, acceptable)
        } else {
            _applyTemp();  // in-place update via hyprctl, no restart, no reset to normal
        }
    }

    function recheck(): void {
        whichProc.running = true;
    }

    function _start(): void {
        hyprsunsetProc.running = true;
    }

    function _stop(): void {
        _pendingTempUpdate = false;
        hyprsunsetProc.running = false;
    }

    function _applyTemp(): void {
        if (hyprctlProc.running) {
            _pendingTempUpdate = true;  // coalesce: apply latest _activeTemp when current call finishes
        } else {
            hyprctlProc.running = true;
        }
    }

    onAvailableChanged: {
        if (available && enabled) {
            _activeTemp = temperature;
            _start();
        } else if (!available) {
            _stop();
        }
    }

    Process {
        id: hyprsunsetProc
        command: ["hyprsunset", "-t", String(root._activeTemp)]
    }

    // Short-lived process: updates the running hyprsunset instance in-place via IPC
    Process {
        id: hyprctlProc
        command: ["hyprctl", "hyprsunset", "temperature", String(root._activeTemp)]
        onRunningChanged: {
            if (!running && root._pendingTempUpdate) {
                root._pendingTempUpdate = false;
                running = true;  // fire again with latest _activeTemp
            }
        }
    }

    Process {
        id: whichProc
        running: true
        command: ["which", "hyprsunset"]
        onExited: code => root.available = (code === 0)
    }
}
