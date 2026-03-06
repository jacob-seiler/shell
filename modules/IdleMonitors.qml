pragma ComponentBehavior: Bound

import "lock"
import qs.config
import qs.services
import Caelestia.Internal
import Quickshell
import Quickshell.Wayland
import QtQuick

Scope {
    id: root

    required property Lock lock
    readonly property bool enabled: !Config.general.idle.inhibitWhenAudio || !Players.list.some(p => p.isPlaying)

    function handleIdleAction(action: var): void {
        if (!action)
            return;

        if (action === "lock")
            lock.lock.locked = true;
        else if (action === "unlock")
            lock.lock.locked = false;
        else if (typeof action === "string")
            Hypr.dispatch(action);
        else
            Quickshell.execDetached(action);
    }

    LogindManager {
        onAboutToSleep: {
            if (Config.general.idle.lockBeforeSleep)
                root.lock.lock.locked = true;
        }
        onLockRequested: root.lock.lock.locked = true
        onUnlockRequested: root.lock.lock.unlock()
    }

    Variants {
        model: Config.general.idle.timeouts

        IdleMonitor {
            required property var modelData

            enabled: root.enabled && (modelData.enabled ?? true)
            timeout: modelData.timeout
            respectInhibitors: modelData.respectInhibitors ?? true
            onIsIdleChanged: root.handleIdleAction(isIdle ? modelData.idleAction : modelData.returnAction)
        }
    }

    IdleMonitor {
        id: dimMonitor

        readonly property int screenOffTimeout: {
            const t = Config.general.idle.timeouts;
            for (let i = 0; i < t.length; i++) {
                if (t[i].idleAction === "dpms off")
                    return t[i].timeout;
            }
            return -1;
        }
        readonly property int dimTimeout: {
            if (screenOffTimeout <= 0)
                return -1;
            const dur = Config.general.idle.dimPreviewDuration ?? 10;
            return Math.max(1, screenOffTimeout - dur);
        }

        enabled: root.enabled && (Config.general.idle.dimBeforeScreenOff ?? true) && dimTimeout > 0
        timeout: Math.max(1, dimTimeout)
        respectInhibitors: true

        onIsIdleChanged: {
            if (isIdle) {
                Brightness.dim(Config.general.idle.dimLevel ?? 0.1);
            } else {
                Brightness.undim();
            }
        }
    }
}
