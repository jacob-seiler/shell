pragma ComponentBehavior: Bound

import ".."
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 2

    property string time: "00:00"
    signal timeModified(string time)

    readonly property int _h: {
        const p = time.split(":");
        return Math.max(0, Math.min(23, parseInt(p[0]) || 0));
    }
    readonly property int _m: {
        const p = time.split(":");
        return Math.max(0, Math.min(59, parseInt(p[1]) || 0));
    }

    // Which segment keyboard Up/Down targets (0=HH, 1=MM)
    property int _activeSeg: 0

    property string _hhDisplay: "00"
    property string _mmDisplay: "00"

    onTimeChanged: {
        if (!hhField.activeFocus)
            _hhDisplay = String(_h).padStart(2, '0');
        if (!mmField.activeFocus)
            _mmDisplay = String(_m).padStart(2, '0');
    }

    Component.onCompleted: {
        _hhDisplay = String(_h).padStart(2, '0');
        _mmDisplay = String(_m).padStart(2, '0');
    }

    function _update(h: int, m: int): void {
        const t = String(h).padStart(2, '0') + ":" + String(m).padStart(2, '0');
        time = t;
        timeModified(t);
    }

    function _incHH(): void {
        const v = _h >= 23 ? 0 : _h + 1;
        _hhDisplay = String(v).padStart(2, '0');
        hhField.text = _hhDisplay;
        _update(v, _m);
        hhField.forceActiveFocus();
    }
    function _decHH(): void {
        const v = _h <= 0 ? 23 : _h - 1;
        _hhDisplay = String(v).padStart(2, '0');
        hhField.text = _hhDisplay;
        _update(v, _m);
        hhField.forceActiveFocus();
    }
    function _incMM(): void {
        const v = _m >= 59 ? 0 : _m + 1;
        _mmDisplay = String(v).padStart(2, '0');
        mmField.text = _mmDisplay;
        _update(_h, v);
        mmField.forceActiveFocus();
    }
    function _decMM(): void {
        const v = _m <= 0 ? 59 : _m - 1;
        _mmDisplay = String(v).padStart(2, '0');
        mmField.text = _mmDisplay;
        _update(_h, v);
        mmField.forceActiveFocus();
    }

    function _inc(): void {
        if (_activeSeg === 0) _incHH(); else _incMM();
    }
    function _dec(): void {
        if (_activeSeg === 0) _decHH(); else _decMM();
    }

    // ── Top button row (▲HH  ▲MM) ─────────────────────────────────────────────
    Item {
        implicitWidth: container.implicitWidth
        Layout.preferredHeight: container.anyFocused ? topRow.implicitHeight : 0
        opacity: container.anyFocused ? 1 : 0
        clip: true

        Behavior on Layout.preferredHeight {
            Anim {}
        }
        Behavior on opacity {
            Anim {}
        }

        RowLayout {
            id: topRow
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: Appearance.spacing.small

            Item {
                implicitWidth: Appearance.padding.normal
            }

            StyledRect {
                radius: Appearance.rounding.small
                color: Colours.palette.m3primary
                implicitWidth: 28
                implicitHeight: upHHIcon.implicitHeight + Appearance.padding.small * 2

                StateLayer {
                    id: upHHState
                    color: Colours.palette.m3onPrimary
                    onPressAndHold: holdTimer.start()
                    onReleased: holdTimer.stop()
                    function onClicked(): void {
                        root._incHH();
                    }
                }

                MaterialIcon {
                    id: upHHIcon
                    anchors.centerIn: parent
                    text: "keyboard_arrow_up"
                    color: Colours.palette.m3onPrimary
                }
            }

            Item {
                Layout.fillWidth: true
            }

            StyledRect {
                radius: Appearance.rounding.small
                color: Colours.palette.m3primary
                implicitWidth: 28
                implicitHeight: upMMIcon.implicitHeight + Appearance.padding.small * 2

                StateLayer {
                    id: upMMState
                    color: Colours.palette.m3onPrimary
                    onPressAndHold: holdTimer.start()
                    onReleased: holdTimer.stop()
                    function onClicked(): void {
                        root._incMM();
                    }
                }

                MaterialIcon {
                    id: upMMIcon
                    anchors.centerIn: parent
                    text: "keyboard_arrow_up"
                    color: Colours.palette.m3onPrimary
                }
            }

            Item {
                implicitWidth: Appearance.padding.normal
            }
        }
    }

    // ── Unified container ─────────────────────────────────────────────────────
    StyledRect {
        id: container

        readonly property bool anyFocused: hhField.activeFocus || mmField.activeFocus

        radius: Appearance.rounding.small
        border.width: 1
        border.color: anyFocused ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.3)
        color: hoverArea.containsMouse || anyFocused ? Colours.layer(Colours.palette.m3surfaceContainer, 3) : Colours.layer(Colours.palette.m3surfaceContainer, 2)

        implicitWidth: innerRow.implicitWidth + Appearance.padding.normal * 2
        implicitHeight: innerRow.implicitHeight + Appearance.padding.small * 2

        Behavior on border.color {
            CAnim {}
        }
        Behavior on color {
            CAnim {}
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.IBeamCursor
            acceptedButtons: Qt.NoButton
        }

        RowLayout {
            id: innerRow
            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            // ── HH field ──────────────────────────────────────────────────────
            StyledTextField {
                id: hhField
                inputMethodHints: Qt.ImhDigitsOnly
                horizontalAlignment: TextInput.AlignHCenter
                implicitWidth: 28
                validator: IntValidator {
                    bottom: 0
                    top: 23
                }

                Binding {
                    target: hhField
                    property: "text"
                    value: root._hhDisplay
                    when: !hhField.activeFocus
                    restoreMode: Binding.RestoreNone
                }

                onActiveFocusChanged: {
                    if (activeFocus) {
                        root._activeSeg = 0;
                        Qt.callLater(selectAll);
                    } else {
                        const n = parseInt(text);
                        if (!isNaN(n))
                            root._update(Math.max(0, Math.min(23, n)), root._m);
                    }
                }
                onAccepted: {
                    const n = parseInt(text);
                    if (!isNaN(n))
                        root._update(Math.max(0, Math.min(23, n)), root._m);
                    mmField.forceActiveFocus();
                }
                Keys.onUpPressed: root._inc()
                Keys.onDownPressed: root._dec()
                Keys.onRightPressed: mmField.forceActiveFocus()

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => event.angleDelta.y > 0 ? root._inc() : root._dec()
                }
            }

            StyledText {
                text: ":"
                font.pointSize: Appearance.font.size.normal
                color: Colours.palette.m3outline
            }

            // ── MM field ──────────────────────────────────────────────────────
            StyledTextField {
                id: mmField
                inputMethodHints: Qt.ImhDigitsOnly
                horizontalAlignment: TextInput.AlignHCenter
                implicitWidth: 28
                validator: IntValidator {
                    bottom: 0
                    top: 59
                }

                Binding {
                    target: mmField
                    property: "text"
                    value: root._mmDisplay
                    when: !mmField.activeFocus
                    restoreMode: Binding.RestoreNone
                }

                onActiveFocusChanged: {
                    if (activeFocus) {
                        root._activeSeg = 1;
                        Qt.callLater(selectAll);
                    } else {
                        const n = parseInt(text);
                        if (!isNaN(n))
                            root._update(root._h, Math.max(0, Math.min(59, n)));
                    }
                }
                onAccepted: {
                    const n = parseInt(text);
                    if (!isNaN(n))
                        root._update(root._h, Math.max(0, Math.min(59, n)));
                }
                Keys.onUpPressed: root._inc()
                Keys.onDownPressed: root._dec()
                Keys.onLeftPressed: hhField.forceActiveFocus()

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => event.angleDelta.y > 0 ? root._inc() : root._dec()
                }
            }
        }
    }

    // ── Bottom button row (▼HH  ▼MM) ──────────────────────────────────────────
    Item {
        implicitWidth: container.implicitWidth
        Layout.preferredHeight: container.anyFocused ? bottomRow.implicitHeight : 0
        opacity: container.anyFocused ? 1 : 0
        clip: true

        Behavior on Layout.preferredHeight {
            Anim {}
        }
        Behavior on opacity {
            Anim {}
        }

        RowLayout {
            id: bottomRow
            anchors.top: parent.top
            width: parent.width
            spacing: Appearance.spacing.small

            Item {
                implicitWidth: Appearance.padding.normal
            }

            StyledRect {
                radius: Appearance.rounding.small
                color: Colours.palette.m3primary
                implicitWidth: 28
                implicitHeight: downHHIcon.implicitHeight + Appearance.padding.small * 2

                StateLayer {
                    id: downHHState
                    color: Colours.palette.m3onPrimary
                    onPressAndHold: holdTimer.start()
                    onReleased: holdTimer.stop()
                    function onClicked(): void {
                        root._decHH();
                    }
                }

                MaterialIcon {
                    id: downHHIcon
                    anchors.centerIn: parent
                    text: "keyboard_arrow_down"
                    color: Colours.palette.m3onPrimary
                }
            }

            Item {
                Layout.fillWidth: true
            }

            StyledRect {
                radius: Appearance.rounding.small
                color: Colours.palette.m3primary
                implicitWidth: 28
                implicitHeight: downMMIcon.implicitHeight + Appearance.padding.small * 2

                StateLayer {
                    id: downMMState
                    color: Colours.palette.m3onPrimary
                    onPressAndHold: holdTimer.start()
                    onReleased: holdTimer.stop()
                    function onClicked(): void {
                        root._decMM();
                    }
                }

                MaterialIcon {
                    id: downMMIcon
                    anchors.centerIn: parent
                    text: "keyboard_arrow_down"
                    color: Colours.palette.m3onPrimary
                }
            }

            Item {
                implicitWidth: Appearance.padding.normal
            }
        }
    }

    Timer {
        id: holdTimer
        interval: 100
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (upHHState.pressed)        root._incHH();
            else if (downHHState.pressed) root._decHH();
            else if (upMMState.pressed)   root._incMM();
            else if (downMMState.pressed) root._decMM();
        }
    }
}
