pragma ComponentBehavior: Bound

import qs.config
import "../../dashboard/dash" as DashComponents
import QtQuick

Item {
    id: root

    implicitWidth: Config.bar.sizes.calendarWidth
    implicitHeight: calendar.implicitHeight

    QtObject {
        id: calState
        property date currentDate: new Date()
    }

    DashComponents.Calendar {
        id: calendar

        anchors.left: parent.left
        anchors.right: parent.right

        state: calState
    }
}
