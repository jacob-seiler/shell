import QtQuick

QtObject {
    id: root

    required property Flickable target

    // Tuning constants
    readonly property real scrollSpeed: 3.0         // multiplier for scroll distance and momentum
    readonly property real momentumFactor: 0.6      // how far momentum carries after lift
    readonly property int animDuration: 800         // momentum glide duration (ms)
    readonly property real accelCoeff: 0.05         // per-pixel acceleration during active scroll
    readonly property real minVelocity: 50          // minimum px/s to trigger momentum
    readonly property real carryThreshold: 200      // minimum px/s to compound a previous glide
    readonly property int trackingWindow: 150       // velocity sampling window (ms)

    // Momentum accumulation state
    property real _carriedVy: 0
    property real _launchedVy: 0
    property real _animStartTime: 0

    function handleWheel(event) {
        if (event.phase === Qt.ScrollBegin) {
            // Capture remaining velocity from any in-progress glide so the next
            // flick can add to it rather than reset. For OutQuad, velocity decays
            // linearly: remaining = launchedVy * (1 - elapsed/duration).
            const elapsed = Date.now() - _animStartTime;
            const progress = Math.min(1.0, elapsed / animDuration);
            _carriedVy = _launchedVy * (1.0 - progress);
            _anim.stop();
            _tracker.clear();
        } else if (event.phase === Qt.ScrollEnd) {
            // Only compound carry into a new flick if the tracker shows clear scroll
            // intent (velocity above threshold). A catch gesture may still move slightly,
            // producing a low-velocity tracker reading — in that case discard the carry.
            const trackerVy = _tracker.velocity();
            const vy = Math.abs(trackerVy) > carryThreshold ? trackerVy + _carriedVy : trackerVy;
            _carriedVy = 0;
            const minY = target.originY;
            const maxY = target.contentHeight - target.height + target.originY;
            const wouldOvershoot = (vy < 0 && target.contentY >= maxY) || (vy > 0 && target.contentY <= minY);
            if (Math.abs(vy) > minVelocity && !wouldOvershoot) {
                _launchedVy = vy;
                _animStartTime = Date.now();
                _anim.from = target.contentY;
                _anim.to = target.contentY - vy * momentumFactor;
                _anim.start();
            }
            _tracker.clear();
        } else if (event.pixelDelta.y !== 0) {
            const dy = event.pixelDelta.y * scrollSpeed;
            _anim.stop();
            target.contentY = Math.max(target.originY, Math.min(target.contentHeight - target.height + target.originY, target.contentY - dy * (1.0 + Math.abs(dy) * accelCoeff)));
            _tracker.addSample(dy);
        }
    }

    property QtObject _tracker: QtObject {
        property var yDeltas: []
        property var yTimes: []

        function addSample(dy) {
            const now = Date.now();
            yDeltas.push(dy);
            yTimes.push(now);
            while (yTimes.length > 0 && now - yTimes[0] > root.trackingWindow) {
                yDeltas.shift();
                yTimes.shift();
            }
        }

        function velocity() {
            if (yTimes.length < 2)
                return 0;
            const dt = (yTimes[yTimes.length - 1] - yTimes[0]) / 1000;
            return dt === 0 ? 0 : yDeltas.reduce((s, d) => s + d, 0) / dt;
        }

        function clear() {
            yDeltas = [];
            yTimes = [];
        }
    }

    // Stop momentum animation the moment contentY hits a boundary rather than
    // decelerating into it, so the end-of-list stop feels abrupt and natural.
    property Connections _boundaryWatcher: Connections {
        target: root.target
        function onContentYChanged() {
            if (!_anim.running) return;
            const t = root.target;
            const minY = t.originY;
            const maxY = t.contentHeight - t.height + t.originY;
            if (_anim.to < minY && t.contentY <= minY) {
                _anim.stop();
                t.contentY = minY;
            } else if (_anim.to > maxY && t.contentY >= maxY) {
                _anim.stop();
                t.contentY = maxY;
            }
        }
    }

    property NumberAnimation _anim: NumberAnimation {
        target: root.target
        property: "contentY"
        duration: root.animDuration
        easing.type: Easing.OutQuad
    }
}
