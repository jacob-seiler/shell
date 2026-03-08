pragma Singleton

import qs.config
import qs.utils
import Caelestia
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Searcher {
    id: root

    property var _pendingKeyboardLaunch: null
    property var _pendingCursorPos: null

    Process {
        id: _cursorPosProc
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(", ");
                const x = parseInt(parts[0]);
                const y = parseInt(parts[1]);
                const entry = root._pendingKeyboardLaunch;
                root._pendingKeyboardLaunch = null;
                root._pendingCursorPos = { x, y };
                root._doLaunch(entry, `[float;move ${x} ${y}]`);
            }
        }
    }

    Process {
        id: _activeWindowProc
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const info = JSON.parse(text.trim());
                const pos = root._pendingCursorPos;
                root._pendingCursorPos = null;
                const newX = Math.round(pos.x - info.size[0] / 2);
                const newY = Math.round(pos.y - info.size[1] / 2);
                Hyprland.dispatch(`movewindowpixel exact ${newX} ${newY},address:${info.address}`);
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "openwindow" && root._pendingCursorPos !== null) {
                _activeWindowProc.running = true;
            }
        }
    }

    function launch(entry: DesktopEntry, fromKeyboard = false): void {
        appDb.incrementFrequency(entry.id);

        const floatingApps = Config.launcher.floatingApps;
        const isFloating = floatingApps.length > 0 && floatingApps.indexOf(entry.id) !== -1;

        if (isFloating && fromKeyboard) {
            _pendingKeyboardLaunch = entry;
            _cursorPosProc.running = true;
        } else {
            _doLaunch(entry, isFloating ? "[float]" : null);
        }
    }

    function _doLaunch(entry, floatRule): void {
        if (entry.runInTerminal) {
            const cmd = ["app2unit", "--", ...Config.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...entry.command];
            if (floatRule)
                Hyprland.dispatch("exec " + floatRule + " " + cmd.join(" "));
            else
                Quickshell.execDetached({ command: cmd, workingDirectory: entry.workingDirectory });
        } else {
            const cmd = ["app2unit", "--", ...entry.command];
            if (floatRule)
                Hyprland.dispatch("exec " + floatRule + " " + cmd.join(" "));
            else
                Quickshell.execDetached({ command: cmd, workingDirectory: entry.workingDirectory });
        }
    }

    function search(search: string): list<var> {
        const prefix = Config.launcher.specialPrefix;

        if (search.startsWith(`${prefix}i `)) {
            keys = ["id", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}c `)) {
            keys = ["categories", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}d `)) {
            keys = ["comment", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}e `)) {
            keys = ["execString", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}w `)) {
            keys = ["startupClass", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}g `)) {
            keys = ["genericName", "name"];
            weights = [0.9, 0.1];
        } else if (search.startsWith(`${prefix}k `)) {
            keys = ["keywords", "name"];
            weights = [0.9, 0.1];
        } else {
            keys = ["name"];
            weights = [1];

            if (!search.startsWith(`${prefix}t `))
                return query(search).map(e => e.entry);
        }

        const results = query(search.slice(prefix.length + 2)).map(e => e.entry);
        if (search.startsWith(`${prefix}t `))
            return results.filter(a => a.runInTerminal);
        return results;
    }

    function selector(item: var): string {
        return keys.map(k => item[k]).join(" ");
    }

    list: appDb.apps
    useFuzzy: Config.launcher.useFuzzy.apps

    AppDb {
        id: appDb

        path: `${Paths.state}/apps.sqlite`
        favouriteApps: Config.launcher.favouriteApps
        entries: DesktopEntries.applications.values.filter(a => !Strings.testRegexList(Config.launcher.hiddenApps, a.id))
    }
}
