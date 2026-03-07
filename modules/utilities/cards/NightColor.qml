import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    readonly property string subtitleText: {
        const schedule = Config.services.nightColorSchedule;
        const fmt = Config.services.useTwelveHourClock ? "h:mm ap" : "h:mm";
        if (schedule === "custom") {
            const parts = Config.services.nightColorTo.split(":").map(Number);
            const d = new Date(); d.setHours(parts[0], parts[1], 0, 0);
            return qsTr("On until %1").arg(Qt.formatTime(d, fmt));
        }
        if (schedule === "sunset" && Weather.cc) {
            return qsTr("On until %1").arg(Qt.formatTime(new Date(Weather.cc.sunrise), fmt));
        }
        return qsTr("Night color active");
    }

    Layout.fillWidth: true
    implicitHeight: NightColor.enabled ? layout.implicitHeight + Appearance.padding.large * 2 : 0
    opacity: NightColor.enabled ? 1 : 0
    scale: NightColor.enabled ? 1 : 0.95
    visible: NightColor.enabled || implicitHeight > 0

    radius: Appearance.rounding.normal
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    RowLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        StyledRect {
            implicitWidth: implicitHeight
            implicitHeight: icon.implicitHeight + Appearance.padding.smaller * 2

            radius: Appearance.rounding.full
            color: Colours.palette.m3secondary

            MaterialIcon {
                id: icon

                anchors.centerIn: parent
                text: "nightlight"
                color: Colours.palette.m3onSecondary
                font.pointSize: Appearance.font.size.large
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Night Color")
                font.pointSize: Appearance.font.size.normal
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.subtitleText
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.small
                elide: Text.ElideRight
            }
        }

        StyledSwitch {
            checked: NightColor.enabled
            onToggled: NightColor.setEnabled(checked)
        }
    }

    Behavior on implicitHeight {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    Behavior on opacity {
        Anim {
            duration: Appearance.anim.durations.small
        }
    }

    Behavior on scale {
        Anim {}
    }
}
