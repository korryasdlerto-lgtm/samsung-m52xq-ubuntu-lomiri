/*
 * Copyright (C) 2015-2016 Canonical Ltd.
 *
 * This file is part of Lomiri Clock App
 *
 * Lomiri Clock App is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Lomiri Clock App is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.12
import ClockApp.Stopwatch 1.0
import Lomiri.Components 1.3

import "../components"

Item {
    id: _stopwatchPage
    objectName: "stopwatchPage"

    property alias isRunning: stopwatchEngine.running
    // m52xq: in landscape there is no height left for the lap list under the face: face on the left, buttons and laps on the right
    readonly property bool m52xqLand: width > height

    Component.onCompleted: {
        console.log("[LOG]: Stopwatch Page Loaded")
    }

    StopwatchEngine {
        id: stopwatchEngine
    }

    StopwatchFace {
        id: stopwatch
        objectName: "stopwatch"

        milliseconds: stopwatchEngine.totalTimeOfStopwatch

        anchors {
            top: parent.top
            topMargin: units.gu(4)
            horizontalCenter: parent.horizontalCenter
            horizontalCenterOffset: _stopwatchPage.m52xqLand ? -parent.width / 4 : 0
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (stopwatchEngine.running) {
                    stopwatchEngine.pauseStopwatch();
                } else {
                    stopwatchEngine.startStopwatch();
                }
            }
        }
    }

    Item {
        id: buttonRow

        width: parent.width - units.gu(4)
        height: units.gu(4)
        anchors {
            top: _stopwatchPage.m52xqLand ? parent.top : stopwatch.bottom
            topMargin: units.gu(4)
            left: _stopwatchPage.m52xqLand ? parent.horizontalCenter : parent.left
            right: parent.right
            margins: units.gu(2)
        }

        Button {
            id: startStopButton
            objectName: "startAndStopButton"

            width: parent.width / 2 - units.gu(1)
            height: units.gu(4)
            x: stopwatchEngine.previousTimeOfStopwatch !== 0 || stopwatchEngine.running ? parent.width - width : (parent.width - width) / 2
            color: !stopwatchEngine.running ? theme.palette.normal.positive : theme.palette.selected.focus
            text: stopwatchEngine.running ? i18n.tr("Stop") : (stopwatchEngine.previousTimeOfStopwatch === 0 ? i18n.tr("Start") : i18n.tr("Resume"))
            onClicked: {
                if (stopwatchEngine.running) {
                    stopwatchEngine.pauseStopwatch();
                } else {
                    stopwatchEngine.startStopwatch();
                }
            }
            Behavior on x {
                LomiriNumberAnimation{
                    duration: LomiriAnimation.BriskDuration
                }
            }
        }

        Button {
            id: lapButton
            objectName: "lapAndClearButton"

            text: stopwatchEngine.running ? i18n.tr("Lap") : i18n.tr("Clear")
            width: parent.width / 2 - units.gu(1)
            height: units.gu(4)
            x: stopwatchEngine.previousTimeOfStopwatch !== 0 || stopwatchEngine.running ? 0 : (width - parent.width) / 2
            visible:  stopwatchEngine.previousTimeOfStopwatch !== 0 || stopwatchEngine.running
            onClicked: {
                if (stopwatchEngine.running) {
                    stopwatchEngine.addLap()
                } else {
                    stopwatchEngine.clearStopwatch()
                    listview.interactive = true
                }
            }
            Behavior on x {
                LomiriNumberAnimation{
                    duration: LomiriAnimation.BriskDuration
                }
            }
        }
    }


   NestedListviewsHack {
       z:10
       parentListView : listview
       nestedListView : lapListView
   }

   LapListView {
        id: lapListView
        objectName: "lapsList"
        anchors {
            top: buttonRow.bottom
            bottom: parent.bottom
            left: _stopwatchPage.m52xqLand ? parent.horizontalCenter : parent.left
            right: parent.right
            topMargin: units.gu(1)
        }
        visible: stopwatchEngine.totalTimeOfStopwatch !== 0
        model: stopwatchEngine
    }
}
