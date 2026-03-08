pragma Singleton

import qs.config
import qs.services
import Caelestia.Internal
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
    property bool _immediateApplyPending: false

    property int rampDuration: Config.services.nightColorRampDuration ?? 60

    property bool _rampActive: false
    property string _rampDirection: ""   // "up" | "down"
    property int _rampFromTemp: 6500
    property var _rampStartTime: null
    property var _rampEndTime: null
    property bool _rampCancelledThisNight: false

    function _getBoundaries(): var {
        if (Config.services.nightColorSchedule === "sunset") {
            if (!Weather.cc) return null;
            const sr = new Date(Weather.cc.sunrise);
            const ss = new Date(Weather.cc.sunset);
            return { from: ss.getHours() * 60 + ss.getMinutes(),
                     to:   sr.getHours() * 60 + sr.getMinutes() };
        }
        const parts = s => s.split(":").map(Number);
        const [fh, fm] = parts(Config.services.nightColorFrom ?? "20:00");
        const [th, tm] = parts(Config.services.nightColorTo ?? "07:00");
        return { from: fh * 60 + fm, to: th * 60 + tm };
    }

    function _inMinuteRange(cur: int, start: int, end: int): bool {
        if (start === end) return false;
        return start < end ? (cur >= start && cur < end)
                           : (cur >= start || cur < end);
    }

    function _getSchedulePhase(): string {
        const b = _getBoundaries();
        if (!b) return "day";
        const c = new Date();
        const cur = c.getHours() * 60 + c.getMinutes();
        const nightMins = b.from < b.to ? (b.to - b.from) : (1440 - b.from + b.to);
        const ramp = (rampDuration * 2 >= nightMins) ? 0 : rampDuration;

        if (ramp > 0 && _inMinuteRange(cur, (b.from - ramp + 1440) % 1440, b.from)) return "ramp_up";
        if (ramp > 0 && _inMinuteRange(cur, (b.to   - ramp + 1440) % 1440, b.to))   return "ramp_down";
        if (_inMinuteRange(cur, b.from, b.to)) return "night";
        return "day";
    }

    function _nextBoundaryDate(which: string): Date {
        const b = _getBoundaries();
        if (!b) return new Date(Date.now() + 3600000);
        const mins = which === "from" ? b.from : b.to;
        const d = new Date();
        d.setHours(Math.floor(mins / 60), mins % 60, 0, 0);
        if (d <= new Date()) d.setDate(d.getDate() + 1);
        return d;
    }

    function _msUntilNextEvent(): int {
        const b = _getBoundaries();
        if (!b) return 3600000;
        const now = new Date();
        const curMs = (now.getHours() * 60 + now.getMinutes()) * 60000
                    + now.getSeconds() * 1000 + now.getMilliseconds();
        const r = rampDuration;
        const events = [
            ((b.from - r + 1440) % 1440) * 60000,
            b.from * 60000,
            ((b.to  - r + 1440) % 1440) * 60000,
            b.to   * 60000
        ];
        let nearest = Infinity;
        for (const e of events) {
            let diff = e - curMs;
            if (diff <= 0) diff += 86400000;
            nearest = Math.min(nearest, diff);
        }
        return Math.max(1000, nearest);
    }

    function _startRampUp(): void {
        _rampCancelledThisNight = false;
        const endDate  = _nextBoundaryDate("from");
        _rampEndTime   = endDate;
        _rampStartTime = new Date(endDate.getTime() - rampDuration * 60000);
        _rampFromTemp  = 6500;
        _rampDirection = "up";
        _rampActive    = true;

        enabled = true;
        // Do not persist to Config here — config stays false for restart detection.
        // _scheduleEnable() saves it when ramp completes and "night" phase fires.

        if (available) {
            _activeTemp = 6500;
            if (hyprsunsetProc.running) _applyTemp();
            else { _immediateApplyPending = true; hyprsunsetProc.running = true; }
        }
        rampTimer.start();
    }

    function _startRampDown(): void {
        const endDate  = _nextBoundaryDate("to");
        _rampEndTime   = endDate;
        _rampStartTime = new Date(endDate.getTime() - rampDuration * 60000);
        _rampFromTemp  = _activeTemp;
        _rampDirection = "down";
        _rampActive    = true;
        rampTimer.start();
    }

    function _cancelRamp(): void {
        rampTimer.stop();
        _rampActive    = false;
        _rampDirection = "";
    }

    function _updateRamp(): void {
        if (!_rampActive || !_rampEndTime) return;
        const now      = new Date();
        const duration = _rampEndTime.getTime() - _rampStartTime.getTime();
        const progress = Math.min(1.0, (now.getTime() - _rampStartTime.getTime()) / duration);
        const toTemp   = _rampDirection === "up" ? temperature : 6500;
        const newTemp  = Math.round(_rampFromTemp + (toTemp - _rampFromTemp) * progress);

        if (available) {
            _activeTemp = newTemp;
            if (hyprsunsetProc.running) _applyTemp();
        }

        if (progress >= 1.0) {
            const dir = _rampDirection;   // capture before _cancelRamp clears it
            _cancelRamp();
            if (dir === "down") {
                setEnabled(false);
                _rampCancelledThisNight = false;
            }
            _scheduleNext();
        }
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
        const phase = _getSchedulePhase();
        switch (phase) {
        case "ramp_up":
            if (!_rampActive && !_rampCancelledThisNight && !enabled)
                _startRampUp();
            break;
        case "night":
            _cancelRamp();
            if (!enabled && !_rampCancelledThisNight) _scheduleEnable();
            _rampCancelledThisNight = false;
            break;
        case "ramp_down":
            if (!_rampActive && !_rampCancelledThisNight && enabled)
                _startRampDown();
            break;
        case "day":
            _cancelRamp();
            if (enabled) { setEnabled(false); _rampCancelledThisNight = false; }
            break;
        }
    }

    function _scheduleNext(): void {
        const schedule = Config.services.nightColorSchedule;
        if (schedule !== "custom" && schedule !== "sunset") return;
        if (_rampActive) return;  // rampTimer is running; scheduleTimer not needed until ramp ends
        scheduleTimer.interval = _msUntilNextEvent();
        scheduleTimer.restart();
    }

    function _resetAndCheck(): void {
        _cancelRamp();
        _rampCancelledThisNight = false;
        _checkSchedule();
        _scheduleNext();
    }

    function setEnabled(val: bool): void {
        if (_rampActive) {
            _cancelRamp();
            _rampCancelledThisNight = true;
        }
        enabled = val;
        Config.services.nightColor = val;
        Config.save();
        if (val && available) {
            _activeTemp = temperature;
            _start();
        } else if (!val) {
            _stop();
        }
        _scheduleNext();
    }

    function setTemperature(val: int): void {
        temperature = val;
        Config.services.nightColorTemp = val;
        Config.save();
        if (_rampActive && _rampDirection === "up") {
            _rampFromTemp  = _activeTemp;   // capture current interpolated position
            _rampStartTime = new Date();    // re-time ramp from now → remaining time
            return;                         // let rampTimer apply temp, don't jump
        }
        _activeTemp = val;
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
        id: rampTimer
        interval: 10000
        repeat: true
        onTriggered: root._updateRamp()
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
            const schedule = Config.services.nightColorSchedule;
            if (schedule === "custom" || schedule === "sunset")
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

    Connections {
        target: Weather
        function onCcChanged(): void {
            if (Config.services.nightColorSchedule === "sunset")
                root._resetAndCheck();
        }
    }

    LogindManager {
        onResumed: root._resetAndCheck()
    }

    Component.onCompleted: {
        const schedule = Config.services.nightColorSchedule;
        if (schedule === "custom" || schedule === "sunset")
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
