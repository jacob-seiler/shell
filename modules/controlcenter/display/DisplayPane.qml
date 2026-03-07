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

    property int nightColorTemp: NightColor.temperature
    property string nightColorSchedule: "off"
    property string nightColorFrom: "20:00"
    property string nightColorTo: "07:00"

    function _readNightColorConfig(): void {
        nightColorSchedule = Config.services.nightColorSchedule ?? "off";
        nightColorFrom = Config.services.nightColorFrom ?? "20:00";
        nightColorTo = Config.services.nightColorTo ?? "07:00";
    }

    Component.onCompleted: _readNightColorConfig()

    Connections {
        target: Config
        function onLoaded(): void { root._readNightColorConfig(); }
    }

    property bool idleLockBeforeSleep: Config.general.idle.lockBeforeSleep ?? true
    property bool idleInhibitWhenAudio: Config.general.idle.inhibitWhenAudio ?? true
    property bool idleDimBeforeScreenOff: Config.general.idle.dimBeforeScreenOff ?? true
    property int idleLockTimeout: Config.general.idle.timeouts[0]?.timeout ?? 180
    property int idleScreenOffTimeout: Config.general.idle.timeouts[1]?.timeout ?? 300
    property int idleSleepTimeout: Config.general.idle.timeouts[2]?.timeout ?? 600

    function saveIdleConfig(): void {
        Config.general.idle.lockBeforeSleep = root.idleLockBeforeSleep;
        Config.general.idle.inhibitWhenAudio = root.idleInhibitWhenAudio;
        Config.general.idle.dimBeforeScreenOff = root.idleDimBeforeScreenOff;
        const orig = Config.general.idle.timeouts;
        const timeouts = [];
        for (let i = 0; i < orig.length; i++) {
            timeouts.push(Object.assign({}, orig[i]));
        }
        if (timeouts.length >= 1)
            timeouts[0].timeout = root.idleLockTimeout;
        if (timeouts.length >= 2)
            timeouts[1].timeout = root.idleScreenOffTimeout;
        if (timeouts.length >= 3)
            timeouts[2].timeout = root.idleSleepTimeout;
        Config.general.idle.timeouts = timeouts;
        Config.save();
    }

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

        MouseArea {
            anchors.fill: parent
            z: -1
            onPressed: mouse => {
                flickable.forceActiveFocus();
                mouse.accepted = false;
            }
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
                title: qsTr("Night Color")
                description: qsTr("Reduce blue light for easier viewing at night")
            }

            SectionContainer {
                SwitchRow {
                    label: qsTr("Active")
                    checked: NightColor.enabled
                    enabled: NightColor.available
                    onToggled: checked => NightColor.setEnabled(checked)
                }

                SliderInput {
                    id: tempSliderInput

                    visible: NightColor.available
                    Layout.fillWidth: true

                    label: qsTr("Color temperature")
                    value: root.nightColorTemp
                    from: 6500
                    to: 2700
                    stepSize: 100
                    suffix: qsTr(" K")
                    validator: IntValidator {
                        bottom: 2700
                        top: 6500
                    }
                    formatValueFunction: val => Math.round(val).toString()
                    parseValueFunction: text => parseInt(text)

                    onValueModified: newValue => {
                        root.nightColorTemp = newValue;
                        NightColor.startPreview(newValue);
                        if (!sliderPressed) NightColor.setTemperature(newValue);
                    }
                    onSliderPressedChanged: {
                        if (!sliderPressed) NightColor.setTemperature(root.nightColorTemp);
                    }
                }

                RowLayout {
                    visible: NightColor.available
                    spacing: Appearance.spacing.normal

                    StyledText {
                        text: qsTr("Schedule")
                        font.pointSize: Appearance.font.size.normal
                    }

                    Item { Layout.fillWidth: true }

                    TextButton {
                        text: qsTr("Off")
                        toggle: false
                        checked: root.nightColorSchedule === "off"
                        type: TextButton.Tonal
                        onClicked: {
                            root.nightColorSchedule = "off";
                            Config.services.nightColorSchedule = "off";
                            Config.save();
                        }
                    }

                    TextButton {
                        text: qsTr("Sunset to Sunrise")
                        toggle: false
                        checked: root.nightColorSchedule === "sunset"
                        type: TextButton.Tonal
                        onClicked: {
                            root.nightColorSchedule = "sunset";
                            Config.services.nightColorSchedule = "sunset";
                            Config.save();
                        }
                    }

                    TextButton {
                        text: qsTr("Custom")
                        toggle: false
                        checked: root.nightColorSchedule === "custom"
                        type: TextButton.Tonal
                        onClicked: {
                            root.nightColorSchedule = "custom";
                            Config.services.nightColorSchedule = "custom";
                            Config.save();
                        }
                    }
                }

                RowLayout {
                    visible: NightColor.available && root.nightColorSchedule === "custom"
                    spacing: Appearance.spacing.normal

                    StyledText {
                        text: qsTr("From")
                        font.pointSize: Appearance.font.size.normal
                    }

                    TimePicker {
                        time: root.nightColorFrom
                        onTimeModified: t => {
                            root.nightColorFrom = t;
                            Config.services.nightColorFrom = t;
                            Config.save();
                        }
                    }

                    StyledText {
                        text: qsTr("To")
                        font.pointSize: Appearance.font.size.normal
                    }

                    TimePicker {
                        time: root.nightColorTo
                        onTimeModified: t => {
                            root.nightColorTo = t;
                            Config.services.nightColorTo = t;
                            Config.save();
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    visible: !NightColor.available
                    spacing: Appearance.spacing.small

                    MaterialIcon {
                        text: "warning"
                        color: Colours.palette.m3error
                        font.pointSize: Appearance.font.size.normal
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("hyprsunset is not installed")
                        color: Colours.palette.m3error
                        font.pointSize: Appearance.font.size.small
                    }

                    IconButton {
                        type: IconButton.Text
                        icon: "refresh"
                        onClicked: NightColor.recheck()
                    }
                }
            }

            SectionHeader {
                title: qsTr("Idle")
                description: qsTr("Configure screen lock and sleep timers")
            }

            SectionContainer {
                contentSpacing: Appearance.spacing.normal

                SwitchRow {
                    label: qsTr("Lock before sleep")
                    checked: root.idleLockBeforeSleep
                    onToggled: checked => {
                        root.idleLockBeforeSleep = checked;
                        root.saveIdleConfig();
                    }
                }

                SwitchRow {
                    label: qsTr("Stay awake while audio is playing")
                    checked: root.idleInhibitWhenAudio
                    onToggled: checked => {
                        root.idleInhibitWhenAudio = checked;
                        root.saveIdleConfig();
                    }
                }

                SwitchRow {
                    label: qsTr("Dim before screen off")
                    checked: root.idleDimBeforeScreenOff
                    onToggled: checked => {
                        root.idleDimBeforeScreenOff = checked;
                        root.saveIdleConfig();
                    }
                }
            }

            SectionContainer {
                contentSpacing: Appearance.spacing.normal

                SliderInput {
                    Layout.fillWidth: true

                    label: qsTr("Lock screen after")
                    value: root.idleLockTimeout / 60
                    from: 1
                    to: 60
                    stepSize: 1
                    suffix: qsTr(" min")
                    validator: IntValidator {
                        bottom: 1
                        top: 60
                    }
                    formatValueFunction: val => Math.round(val).toString()
                    parseValueFunction: text => parseInt(text)

                    onValueModified: newValue => {
                        root.idleLockTimeout = newValue * 60;
                        root.saveIdleConfig();
                    }
                }

                SliderInput {
                    Layout.fillWidth: true

                    label: qsTr("Screen off after")
                    value: root.idleScreenOffTimeout / 60
                    from: 1
                    to: 60
                    stepSize: 1
                    suffix: qsTr(" min")
                    validator: IntValidator {
                        bottom: 1
                        top: 60
                    }
                    formatValueFunction: val => Math.round(val).toString()
                    parseValueFunction: text => parseInt(text)

                    onValueModified: newValue => {
                        root.idleScreenOffTimeout = newValue * 60;
                        root.saveIdleConfig();
                    }
                }

                SliderInput {
                    Layout.fillWidth: true

                    label: qsTr("Sleep after")
                    value: root.idleSleepTimeout / 60
                    from: 1
                    to: 120
                    stepSize: 1
                    suffix: qsTr(" min")
                    validator: IntValidator {
                        bottom: 1
                        top: 120
                    }
                    formatValueFunction: val => Math.round(val).toString()
                    parseValueFunction: text => parseInt(text)

                    onValueModified: newValue => {
                        root.idleSleepTimeout = newValue * 60;
                        root.saveIdleConfig();
                    }
                }
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
