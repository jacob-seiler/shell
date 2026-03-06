pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Session session

    anchors.fill: parent

    StyledFlickable {
        id: flickable

        anchors.fill: parent
        anchors.margins: Appearance.padding.large * 2
        flickableDirection: Flickable.VerticalFlick
        contentHeight: contentLayout.height

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: flickable
        }

        ColumnLayout {
            id: contentLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Appearance.spacing.normal

            SettingsHeader {
                icon: "battery_full"
                title: qsTr("Battery")
            }

            SectionHeader {
                title: qsTr("Status")
                description: qsTr("Current battery information")
            }

            SectionContainer {
                contentSpacing: Appearance.spacing.normal

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.normal

                        visible: UPower.displayDevice.isLaptopBattery

                        StyledText {
                            text: qsTr("%1%").arg(Math.round(UPower.displayDevice.percentage * 100))
                            font.pointSize: Appearance.font.size.extraLarge
                            font.weight: 700
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        MaterialIcon {
                            text: {
                                const pct = UPower.displayDevice.percentage;
                                if (!UPower.onBattery)
                                    return "battery_charging_full";
                                if (pct > 0.9)
                                    return "battery_full";
                                if (pct > 0.7)
                                    return "battery_5_bar";
                                if (pct > 0.5)
                                    return "battery_4_bar";
                                if (pct > 0.3)
                                    return "battery_3_bar";
                                if (pct > 0.1)
                                    return "battery_2_bar";
                                return "battery_1_bar";
                            }
                            font.pointSize: Appearance.font.size.extraLarge
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.normal

                        visible: UPower.displayDevice.isLaptopBattery

                        StyledText {
                            text: UPower.onBattery ? qsTr("Time remaining") : qsTr("Until charged")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledText {
                            function formatSeconds(s: int, fallback: string): string {
                                const day = Math.floor(s / 86400);
                                const hr = Math.floor(s / 3600) % 60;
                                const min = Math.floor(s / 60) % 60;

                                let comps = [];
                                if (day > 0)
                                    comps.push(`${day} days`);
                                if (hr > 0)
                                    comps.push(`${hr} hours`);
                                if (min > 0)
                                    comps.push(`${min} mins`);

                                return comps.join(", ") || fallback;
                            }

                            text: UPower.onBattery ? formatSeconds(UPower.displayDevice.timeToEmpty, qsTr("Calculating...")) : formatSeconds(UPower.displayDevice.timeToFull, qsTr("Fully charged!"))
                            color: Colours.palette.m3outline
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.normal

                        visible: UPower.displayDevice.isLaptopBattery

                        StyledText {
                            text: qsTr("State")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: {
                                if (!UPower.displayDevice.isLaptopBattery)
                                    return qsTr("No battery");
                                if (UPower.displayDevice.percentage >= 1 && !UPower.onBattery)
                                    return qsTr("Fully charged");
                                return UPower.onBattery ? qsTr("Discharging") : qsTr("Charging");
                            }
                            color: Colours.palette.m3outline
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: !UPower.displayDevice.isLaptopBattery
                        text: qsTr("No battery detected")
                        color: Colours.palette.m3outline
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            SectionHeader {
                title: qsTr("Power Profile")
                description: qsTr("Manage performance and power usage")
            }

            SectionContainer {
                contentSpacing: Appearance.spacing.normal

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.normal

                    Loader {
                        Layout.fillWidth: true

                        active: PowerProfiles.degradationReason !== PerformanceDegradationReason.None

                        height: active ? (item?.implicitHeight ?? 0) : 0

                        sourceComponent: StyledRect {
                            implicitWidth: child.implicitWidth + Appearance.padding.normal * 2
                            implicitHeight: child.implicitHeight + Appearance.padding.smaller * 2

                            color: Colours.palette.m3error
                            radius: Appearance.rounding.normal

                            Column {
                                id: child

                                anchors.centerIn: parent

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: Appearance.spacing.small

                                    MaterialIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.verticalCenterOffset: -font.pointSize / 10

                                        text: "warning"
                                        color: Colours.palette.m3onError
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Performance Degraded")
                                        color: Colours.palette.m3onError
                                        font.family: Appearance.font.family.mono
                                        font.weight: 500
                                    }

                                    MaterialIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.verticalCenterOffset: -font.pointSize / 10

                                        text: "warning"
                                        color: Colours.palette.m3onError
                                    }
                                }

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    text: qsTr("Reason: %1").arg(PerformanceDegradationReason.toString(PowerProfiles.degradationReason))
                                    color: Colours.palette.m3onError
                                }
                            }
                        }
                    }

                    StyledRect {
                        id: profiles

                        property string current: {
                            const p = PowerProfiles.profile;
                            if (p === PowerProfile.PowerSaver)
                                return saver.icon;
                            if (p === PowerProfile.Performance)
                                return perf.icon;
                            return balance.icon;
                        }

                        Layout.alignment: Qt.AlignHCenter

                        implicitWidth: saver.implicitHeight + balance.implicitHeight + perf.implicitHeight + Appearance.padding.normal * 2 + Appearance.spacing.large * 2
                        implicitHeight: Math.max(saver.implicitHeight, balance.implicitHeight, perf.implicitHeight) + Appearance.padding.small * 2

                        color: Colours.tPalette.m3surfaceContainer
                        radius: Appearance.rounding.full

                        StyledRect {
                            id: indicator

                            color: Colours.palette.m3primary
                            radius: Appearance.rounding.full
                            state: profiles.current

                            states: [
                                State {
                                    name: saver.icon

                                    Fill {
                                        item: saver
                                    }
                                },
                                State {
                                    name: balance.icon

                                    Fill {
                                        item: balance
                                    }
                                },
                                State {
                                    name: perf.icon

                                    Fill {
                                        item: perf
                                    }
                                }
                            ]

                            transitions: Transition {
                                AnchorAnimation {
                                    duration: Appearance.anim.durations.normal
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Appearance.anim.curves.emphasized
                                }
                            }
                        }

                        Profile {
                            id: saver

                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Appearance.padding.small

                            profile: PowerProfile.PowerSaver
                            icon: "energy_savings_leaf"
                        }

                        Profile {
                            id: balance

                            anchors.centerIn: parent

                            profile: PowerProfile.Balanced
                            icon: "balance"
                        }

                        Profile {
                            id: perf

                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: Appearance.padding.small

                            profile: PowerProfile.Performance
                            icon: "rocket_launch"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Repeater {
                            model: [
                                { label: qsTr("Power Saver"), icon: "energy_savings_leaf", profile: PowerProfile.PowerSaver },
                                { label: qsTr("Balanced"), icon: "balance", profile: PowerProfile.Balanced },
                                { label: qsTr("Performance"), icon: "rocket_launch", profile: PowerProfile.Performance }
                            ]

                            delegate: StyledText {
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                horizontalAlignment: index === 0 ? Text.AlignLeft : (index === 2 ? Text.AlignRight : Text.AlignHCenter)
                                text: modelData.label
                                font.pointSize: Appearance.font.size.small
                                color: {
                                    const p = PowerProfiles.profile;
                                    if (p === modelData.profile)
                                        return Colours.palette.m3primary;
                                    return Colours.palette.m3outline;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component Fill: AnchorChanges {
        required property Item item

        target: indicator
        anchors.left: item.left
        anchors.right: item.right
        anchors.top: item.top
        anchors.bottom: item.bottom
    }

    component Profile: Item {
        required property string icon
        required property int profile

        implicitWidth: iconItem.implicitHeight + Appearance.padding.small * 2
        implicitHeight: iconItem.implicitHeight + Appearance.padding.small * 2

        StateLayer {
            radius: Appearance.rounding.full
            color: profiles.current === parent.icon ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface

            function onClicked(): void {
                PowerProfiles.profile = parent.profile;
            }
        }

        MaterialIcon {
            id: iconItem

            anchors.centerIn: parent

            text: parent.icon
            font.pointSize: Appearance.font.size.large
            color: profiles.current === text ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            fill: profiles.current === text ? 1 : 0

            Behavior on fill {
                Anim {}
            }
        }
    }
}
