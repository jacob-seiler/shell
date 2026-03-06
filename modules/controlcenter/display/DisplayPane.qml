pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Session session

    readonly property var monitor: Brightness.getMonitor("active") ?? (Brightness.monitors.length > 0 ? Brightness.monitors[0] : null)

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
                icon: "brightness_high"
                title: qsTr("Display")
            }

            SectionHeader {
                title: qsTr("Brightness")
                description: qsTr("Control screen brightness")
            }

            SectionContainer {
                contentSpacing: Appearance.spacing.normal

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.normal

                        StyledText {
                            text: qsTr("Brightness")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledInputField {
                            id: brightnessInput
                            Layout.preferredWidth: 70
                            validator: IntValidator {
                                bottom: 0
                                top: 100
                            }

                            Component.onCompleted: {
                                text = Math.round((root.monitor?.brightness ?? 0) * 100).toString();
                            }

                            Connections {
                                target: root.monitor
                                function onBrightnessChanged() {
                                    if (!brightnessInput.hasFocus) {
                                        brightnessInput.text = Math.round((root.monitor?.brightness ?? 0) * 100).toString();
                                    }
                                }
                            }

                            onTextEdited: text => {
                                if (hasFocus) {
                                    const val = parseInt(text);
                                    if (!isNaN(val) && val >= 0 && val <= 100) {
                                        Brightness.setAutoBrightness(false);
                                        root.monitor?.setBrightness(val / 100);
                                    }
                                }
                            }

                            onEditingFinished: {
                                const val = parseInt(text);
                                if (isNaN(val) || val < 0 || val > 100) {
                                    text = Math.round((root.monitor?.brightness ?? 0) * 100).toString();
                                }
                            }
                        }

                        StyledText {
                            text: "%"
                            color: Colours.palette.m3outline
                            font.pointSize: Appearance.font.size.normal
                        }

                        StyledRect {
                            implicitWidth: implicitHeight
                            implicitHeight: autoIcon.implicitHeight + Appearance.padding.normal * 2

                            radius: Appearance.rounding.normal
                            color: Brightness.autoBrightness ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                            StateLayer {
                                function onClicked(): void {
                                    Brightness.setAutoBrightness(!Brightness.autoBrightness);
                                }
                            }

                            MaterialIcon {
                                id: autoIcon

                                anchors.centerIn: parent
                                text: "brightness_auto"
                                color: Brightness.autoBrightness ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                            }
                        }
                    }

                    StyledSlider {
                        id: brightnessSlider
                        Layout.fillWidth: true
                        implicitHeight: Appearance.padding.normal * 3

                        value: root.monitor?.brightness ?? 0
                        onMoved: {
                            Brightness.setAutoBrightness(false);
                            root.monitor?.setBrightness(value);
                            if (!brightnessInput.hasFocus) {
                                brightnessInput.text = Math.round(value * 100).toString();
                            }
                        }
                    }

                    StyledText {
                        visible: Brightness.autoBrightness
                        text: qsTr("Auto · %1 lux").arg(Brightness.currentLux)
                        color: Colours.palette.m3outline
                        font.pointSize: Appearance.font.size.small
                    }
                }
            }
        }
    }
}
