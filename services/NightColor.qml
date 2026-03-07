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
    property bool _wasInRange: false
    property bool _immediateApplyPending: false

    function _isInRange(): bool {
        const now = new Date();
        const cur = now.getHours() * 60 + now.getMinutes();
        const parts = s => s.split(":").map(Number);
        const [fh, fm] = parts(Config.services.nightColorFrom ?? "20:00");
        const [th, tm] = parts(Config.services.nightColorTo ?? "07:00");
        const from = fh * 60 + fm;
        const to = th * 60 + tm;
        if (from === to) return false;
        return from < to ? (cur >= from && cur < to)
                         : (cur >= from || cur < to);
    }

    function _msUntilNext(): int {
        const now = new Date();
        const curMs = (now.getHours() * 60 + now.getMinutes()) * 60000 + now.getSeconds() * 1000 + now.getMilliseconds();
        const parts = s => s.split(":").map(Number);
        const [fh, fm] = parts(Config.services.nightColorFrom ?? "20:00");
        const [th, tm] = parts(Config.services.nightColorTo ?? "07:00");
        const fromMs = (fh * 60 + fm) * 60000;
        const toMs   = (th * 60 + tm) * 60000;
        const targetMs = _isInRange() ? toMs : fromMs;
        let diff = targetMs - curMs;
        if (diff <= 0) diff += 86400000; // wrap to next day
        return diff;
    }

    function _scheduleEnable(): void {
        enabled = true;
        Config.services.nightColor = true;
        Config.save();
        if (available) {
            _activeTemp = temperature;
            if (hyprsunsetProc.running) {
                _applyTemp();  // already running — instant IPC update, no animation
            } else {
                _immediateApplyPending = true;
                hyprsunsetProc.running = true;
            }
        }
    }

    function _checkSchedule(): void {
        const inRange = _isInRange();
        if (!_wasInRange && inRange) _scheduleEnable();
        if (_wasInRange && !inRange) setEnabled(false);
        _wasInRange = inRange;
    }

    function _scheduleNext(): void {
        if (Config.services.nightColorSchedule !== "custom") return;
        scheduleTimer.interval = _msUntilNext();
        scheduleTimer.restart();
    }

    function _resetAndCheck(): void {
        _wasInRange = false;
        _checkSchedule();
        _scheduleNext();
    }

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

    Timer {
        id: scheduleTimer
        repeat: false
        onTriggered: {
            root._checkSchedule();
            root._scheduleNext();
        }
    }

    Connections {
        target: Config.services
        function onNightColorScheduleChanged() {
            if (Config.services.nightColorSchedule === "custom")
                root._resetAndCheck();
            else
                scheduleTimer.stop();
        }
        function onNightColorFromChanged() {
            if (Config.services.nightColorSchedule === "custom")
                root._resetAndCheck();
        }
        function onNightColorToChanged() {
            if (Config.services.nightColorSchedule === "custom")
                root._resetAndCheck();
        }
    }

    Component.onCompleted: {
        if (Config.services.nightColorSchedule === "custom")
            _resetAndCheck();
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
        onRunningChanged: {
            if (running && root._immediateApplyPending) {
                root._immediateApplyPending = false;
                root._applyTemp();
            }
        }
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
