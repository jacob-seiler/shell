import ".."
import QtQuick

ListView {
    id: root

    maximumFlickVelocity: 3000
    flickDeceleration: 600
    boundsBehavior: Flickable.StopAtBounds

    rebound: Transition {
        Anim {
            properties: "x,y"
        }
    }

    ScrollBehavior { id: scroll; target: root }

    WheelHandler {
        acceptedDevices: PointerDevice.TouchPad
        onWheel: event => scroll.handleWheel(event)
    }
}
