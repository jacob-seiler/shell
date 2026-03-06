pragma Singleton
pragma ComponentBehavior: Bound

import qs.config
import qs.components
import qs.components.misc
import Quickshell
import Quickshell.Io
import QtQuick
import Caelestia.Internal

Singleton {
    id: root

    property list<var> ddcMonitors: []
    readonly property list<Monitor> monitors: variants.instances
    property bool appleDisplayPresent: false
    property bool autoBrightness: Config.services.autoBrightness ?? false
    property int currentLux: 0
    property int lastAppliedLux: -1

    function getMonitorForScreen(screen: ShellScreen): var {
        return monitors.find(m => m.modelData === screen);
    }

    function getMonitor(query: string): var {
        if (query === "active") {
            return monitors.find(m => Hypr.monitorFor(m.modelData)?.focused);
        }

        if (query.startsWith("model:")) {
            const model = query.slice(6);
            return monitors.find(m => m.modelData.model === model);
        }

        if (query.startsWith("serial:")) {
            const serial = query.slice(7);
            return monitors.find(m => m.modelData.serialNumber === serial);
        }

        if (query.startsWith("id:")) {
            const id = parseInt(query.slice(3), 10);
            return monitors.find(m => Hypr.monitorFor(m.modelData)?.id === id);
        }

        return monitors.find(m => m.modelData.name === query);
    }

    function luxToBrightness(lux: int): real {
        return Math.max(0.1, Math.min(1.0, Math.log10(Math.max(1, lux)) / 4));
    }

    function applyAutoLux(): void {
        if (!autoBrightness)
            return;
        if (Math.abs(currentLux - lastAppliedLux) <= 20)
            return;
        const monitor = getMonitor("active") ?? (monitors.length > 0 ? monitors[0] : null);
        if (!monitor)
            return;
        const targetBrightness = Math.max(0, Math.min(1, luxToBrightness(currentLux) + monitor.userOffset));
        if (Math.abs(targetBrightness - monitor.brightness) < 0.02)
            return;
        lastAppliedLux = currentLux;
        monitor.suppressOsd = true;
        monitor.setAutoTarget(targetBrightness);
        Qt.callLater(() => { monitor.suppressOsd = false; });
    }

    function setAutoBrightness(enabled: bool): void {
        autoBrightness = enabled;
        Config.services.autoBrightness = enabled;
        Config.save();
        if (enabled) {
            lastAppliedLux = -1;
            for (const m of monitors)
                m.userOffset = 0;
            alsProc.running = true;
        }
    }

    function increaseBrightness(): void {
        const monitor = getMonitor("active");
        if (!monitor)
            return;
        monitor.setBrightness(monitor.brightness + Config.services.brightnessIncrement);
        if (autoBrightness)
            monitor.userOffset = monitor.brightness - luxToBrightness(currentLux);
        else
            setAutoBrightness(false);
    }

    function decreaseBrightness(): void {
        const monitor = getMonitor("active");
        if (!monitor)
            return;
        monitor.setBrightness(monitor.brightness - Config.services.brightnessIncrement);
        if (autoBrightness)
            monitor.userOffset = monitor.brightness - luxToBrightness(currentLux);
        else
            setAutoBrightness(false);
    }

    function dim(targetLevel: real): void {
        for (const m of monitors) {
            if (m.preDimBrightness >= 0)
                continue;
            m.preDimBrightness = m.brightness;
            if (!m.isDdc && !m.isAppleDisplay && m.hwBrightnessInitialized) {
                m.hwAnim.stop();
                m.hwAutoAnim.stop();
                m.hwDimAnim.from = m.animatedHWBrightness;
                m.hwDimAnim.to = Math.min(m.animatedHWBrightness, targetLevel);
                m.hwDimAnim.start();
            } else if (m.isDdc) {
                Quickshell.execDetached(["ddcutil", "-b", m.busNum, "setvcp", "10", Math.round(targetLevel * 100)]);
            } else if (m.isAppleDisplay) {
                Quickshell.execDetached(["asdbctl", "set", Math.round(targetLevel * 101)]);
            }
        }
    }

    function undim(): void {
        for (const m of monitors) {
            if (m.preDimBrightness < 0)
                continue;
            const restoreTo = m.preDimBrightness;
            m.preDimBrightness = -1;
            if (!m.isDdc && !m.isAppleDisplay) {
                m.hwDimAnim.stop();
                m.animatedHWBrightness = restoreTo;
            } else if (m.isDdc) {
                Quickshell.execDetached(["ddcutil", "-b", m.busNum, "setvcp", "10", Math.round(restoreTo * 100)]);
            } else if (m.isAppleDisplay) {
                Quickshell.execDetached(["asdbctl", "set", Math.round(restoreTo * 101)]);
            }
        }
    }

    onCurrentLuxChanged: applyAutoLux()

    onMonitorsChanged: {
        ddcMonitors = [];
        ddcProc.running = true;
    }

    Variants {
        id: variants

        model: Quickshell.screens

        Monitor {}
    }

    Process {
        running: true
        command: ["sh", "-c", "asdbctl get"] // To avoid warnings if asdbctl is not installed
        stdout: StdioCollector {
            onStreamFinished: root.appleDisplayPresent = text.trim().length > 0
        }
    }

    Process {
        id: ddcProc

        command: ["ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: root.ddcMonitors = text.trim().split("\n\n").filter(d => d.startsWith("Display ")).map(d => ({
                        busNum: d.match(/I2C bus:[ ]*\/dev\/i2c-([0-9]+)/)[1],
                        connector: d.match(/DRM connector:\s+(.*)/)[1].replace(/^card\d+-/, "") // strip "card1-"
                    }))
        }
    }

    Process {
        id: alsProc

        command: ["cat", "/sys/bus/iio/devices/iio:device0/in_illuminance_raw"]
        stdout: StdioCollector {
            onStreamFinished: {
                const val = parseInt(text.trim());
                if (!isNaN(val))
                    root.currentLux = val;
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.autoBrightness
        onTriggered: alsProc.running = true
    }

    LogindManager {
        onResumed: {
            root.lastAppliedLux = -1;
            for (const m of root.monitors)
                m.userOffset = 0;
            alsProc.running = true;
        }
    }

    CustomShortcut {
        name: "brightnessUp"
        description: "Increase brightness"
        onPressed: root.increaseBrightness()
    }

    CustomShortcut {
        name: "brightnessDown"
        description: "Decrease brightness"
        onPressed: root.decreaseBrightness()
    }

    IpcHandler {
        target: "brightness"

        function get(): real {
            return getFor("active");
        }

        // Allows searching by active/model/serial/id/name
        function getFor(query: string): real {
            return root.getMonitor(query)?.brightness ?? -1;
        }

        function set(value: string): string {
            return setFor("active", value);
        }

        // Handles brightness value like brightnessctl: 0.1, +0.1, 0.1-, 10%, +10%, 10%-
        function setFor(query: string, value: string): string {
            const monitor = root.getMonitor(query);
            if (!monitor)
                return "Invalid monitor: " + query;

            let targetBrightness;
            if (value.endsWith("%-")) {
                const percent = parseFloat(value.slice(0, -2));
                targetBrightness = monitor.brightness - (percent / 100);
            } else if (value.startsWith("+") && value.endsWith("%")) {
                const percent = parseFloat(value.slice(1, -1));
                targetBrightness = monitor.brightness + (percent / 100);
            } else if (value.endsWith("%")) {
                const percent = parseFloat(value.slice(0, -1));
                targetBrightness = percent / 100;
            } else if (value.startsWith("+")) {
                const increment = parseFloat(value.slice(1));
                targetBrightness = monitor.brightness + increment;
            } else if (value.endsWith("-")) {
                const decrement = parseFloat(value.slice(0, -1));
                targetBrightness = monitor.brightness - decrement;
            } else if (value.includes("%") || value.includes("-") || value.includes("+")) {
                return `Invalid brightness format: ${value}\nExpected: 0.1, +0.1, 0.1-, 10%, +10%, 10%-`;
            } else {
                targetBrightness = parseFloat(value);
            }

            if (isNaN(targetBrightness))
                return `Failed to parse value: ${value}\nExpected: 0.1, +0.1, 0.1-, 10%, +10%, 10%-`;

            monitor.setBrightness(targetBrightness);
            if (root.autoBrightness)
                monitor.userOffset = monitor.brightness - root.luxToBrightness(root.currentLux);
            else
                root.setAutoBrightness(false);

            return `Set monitor ${monitor.modelData.name} brightness to ${+monitor.brightness.toFixed(2)}`;
        }
    }

    component Monitor: QtObject {
        id: monitor

        required property ShellScreen modelData
        readonly property bool isDdc: root.ddcMonitors.some(m => m.connector === modelData.name)
        readonly property string busNum: root.ddcMonitors.find(m => m.connector === modelData.name)?.busNum ?? ""
        readonly property bool isAppleDisplay: root.appleDisplayPresent && modelData.model.startsWith("StudioDisplay")
        property real brightness
        property bool suppressOsd: false
        property real userOffset: 0
        property real queuedBrightness: NaN
        property real animatedHWBrightness: 0
        property int lastAppliedRounded: -1
        property bool hwBrightnessInitialized: false

        // Manual brightness change: short animation matching normal UI transitions
        readonly property NumberAnimation hwAnim: NumberAnimation {
            target: monitor
            property: "animatedHWBrightness"
            duration: Appearance.anim.durations.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.standard
        }

        // Auto-brightness adjustment: slow animation so the screen eases to the new level
        readonly property NumberAnimation hwAutoAnim: NumberAnimation {
            target: monitor
            property: "animatedHWBrightness"
            duration: 5000
            easing.type: Easing.InOutSine
        }

        // Dim animation: smoothly dims to a low level before screen-off
        readonly property NumberAnimation hwDimAnim: NumberAnimation {
            target: monitor
            property: "animatedHWBrightness"
            duration: 2000
            easing.type: Easing.OutCubic
        }

        property real preDimBrightness: -1

        onAnimatedHWBrightnessChanged: {
            if (isDdc || isAppleDisplay)
                return;
            const rounded = Math.round(animatedHWBrightness * 100);
            if (rounded === lastAppliedRounded)
                return;
            lastAppliedRounded = rounded;
            Quickshell.execDetached(["brightnessctl", "s", `${rounded}%`]);
        }

        readonly property Process initProc: Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    if (monitor.isAppleDisplay) {
                        const val = parseInt(text.trim());
                        monitor.brightness = val / 101;
                    } else {
                        const [, , , cur, max] = text.split(" ");
                        monitor.brightness = parseInt(cur) / parseInt(max);
                    }
                    monitor.animatedHWBrightness = monitor.brightness;
                    monitor.lastAppliedRounded = Math.round(monitor.brightness * 100);
                    monitor.hwBrightnessInitialized = true;
                }
            }
        }

        readonly property Timer timer: Timer {
            interval: 500
            onTriggered: {
                if (!isNaN(monitor.queuedBrightness)) {
                    monitor.setBrightness(monitor.queuedBrightness);
                    monitor.queuedBrightness = NaN;
                }
            }
        }

        function setBrightness(value: real): void {
            if (preDimBrightness >= 0) {
                hwDimAnim.stop();
                preDimBrightness = -1;
            }
            value = Math.max(0, Math.min(1, value));
            const rounded = Math.round(value * 100);
            if (Math.round(brightness * 100) === rounded)
                return;

            if (isDdc && timer.running) {
                queuedBrightness = value;
                return;
            }

            brightness = value;

            if (isAppleDisplay)
                Quickshell.execDetached(["asdbctl", "set", rounded]);
            else if (isDdc)
                Quickshell.execDetached(["ddcutil", "-b", busNum, "setvcp", "10", rounded]);
            else if (hwBrightnessInitialized) {
                hwAutoAnim.stop();
                hwAnim.from = animatedHWBrightness;
                hwAnim.to = value;
                hwAnim.start();
            } else {
                animatedHWBrightness = value;
            }

            if (isDdc)
                timer.restart();
        }

        // Called by auto-brightness: animates slowly so the screen eases to the new level.
        // Manual calls to setBrightness() interrupt this animation.
        function setAutoTarget(value: real): void {
            if (preDimBrightness >= 0) {
                hwDimAnim.stop();
                preDimBrightness = -1;
            }
            value = Math.max(0, Math.min(1, value));
            const rounded = Math.round(value * 100);
            if (Math.round(brightness * 100) === rounded)
                return;

            if (isDdc && timer.running) {
                queuedBrightness = value;
                return;
            }

            brightness = value;

            if (isAppleDisplay)
                Quickshell.execDetached(["asdbctl", "set", rounded]);
            else if (isDdc)
                Quickshell.execDetached(["ddcutil", "-b", busNum, "setvcp", "10", rounded]);
            else if (hwBrightnessInitialized) {
                hwAnim.stop();
                hwAutoAnim.from = animatedHWBrightness;
                hwAutoAnim.to = value;
                hwAutoAnim.start();
            } else {
                animatedHWBrightness = value;
            }

            if (isDdc)
                timer.restart();
        }

        function initBrightness(): void {
            if (isAppleDisplay)
                initProc.command = ["asdbctl", "get"];
            else if (isDdc)
                initProc.command = ["ddcutil", "-b", busNum, "getvcp", "10", "--brief"];
            else
                initProc.command = ["sh", "-c", "echo a b c $(brightnessctl g) $(brightnessctl m)"];

            initProc.running = true;
        }

        onBusNumChanged: initBrightness()
        Component.onCompleted: initBrightness()
    }
}
