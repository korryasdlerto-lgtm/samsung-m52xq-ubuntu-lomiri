/*
 * Copyright (C) 2014-2016 Canonical Ltd.
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
import ClockApp.WorldClock 1.0
import U1db 1.0 as U1db
import ClockApp.Alarm 1.0
import Lomiri.Components 1.3
import QtQuick.Window 2.2
import Qt.labs.settings 1.0
import UserMetrics 0.1
import "components"

Window {
    id: rootWindow

    // Property to store the state of an application (active or suspended)
    property bool applicationState: Qt.application.active

    /*
      The width and height defined below are the same dimension used by the
      designers in the clock visual spec.
    */

    minimumWidth: units.gu(40)

    onApplicationStateChanged: {
        localTimeSource.update()
        Date.timeZoneUpdated()
        /*
         Reload the alarm model when the clock app gains focus to refresh
         the alarm page UI in the case of alarm notifications.
        */
        if(applicationState && !mainPage.isColdStart && (mainStack.currentPage.isMainPage
                                                         || mainStack.currentPage.isAlarmPage)) {
            console.log("[LOG]: Alarm Database unloaded")
            alarmModelLoader.source = ""
            alarmModelLoader.source = Qt.resolvedUrl("alarm/AlarmModelComponent.qml")
        }
    }

    MainView {
        id: clockApp

        // objectName for functional testing purposes (autopilot-qt5)
        objectName: "clockMainView"

        theme.name: clockAppSettings.theme
        backgroundColor: theme.palette.normal.background

        anchors.fill: parent

        anchorToKeyboard: true

        Settings {
            id:clockAppSettings
            property string theme: ""
            property string defaultAlarmSound:""
            property int    alarmListSortOrder: Qt.AscendingOrder
        }

        // Database to store the user preferences locally
        U1db.Database {
            id: clockDB
            path: "user-preferences"
        }

        // Document to store clock mode chosen by user
        U1db.Document {
            id: clockModeDocument
            create: true
            database: clockDB
            docId: "clockModeDocument"
            defaults: { "digitalMode": false }
        }

        U1db.Document {
            id: userLocationDocument
            create: true
            database: clockDB
            docId: "userLocationDocument"
            defaults: { "lat": "NaN", "long": "Nan", "location": "Null" }
        }

        DateTime {
            id: localTimeSource
            updateInterval: 1000
        }

        AlarmSound {
            id: alarmSoundHelper
            // Create CustomSounds directory if it does not exist on app startup
            Component.onCompleted: createCustomAlarmSoundDirectory()
        }

        PageStack {
            id: mainStack
            // onCurrentPageChanged: {
            //    if(depth=0) {
            //       console.log("page stack depth = 0!")
            //       currentPage.bottomEdgeLoader.reload()
            //    }
            // }
            // property var bottomEdgePointer: mainPage.bottomEdgeLoader

            Component.onCompleted: push(mainPage)

            MainPage {
                id: mainPage

                readonly property bool isMainPage: true

                Loader {
                    id: alarmModelLoader
                    asynchronous: false
                }

                alarmModel: alarmModelLoader.item
                /*
               FIXME: When the upstream QT bug at https://bugreports.qt.io/browse/QTBUG-40275 is fixed
               it will be possible to receive a datetime object directly for notLocalizedDateTimeString variable.
               */
                notLocalizedDateTimeString: localTimeSource.notLocalizedCurrentDateTimeString
                localizedTimeString: localTimeSource.localizedCurrentTimeString
                localizedDateString: localTimeSource.localizedCurrentDateString
            }
        }
        theme.onNameChanged: mainPage.reloadBottomEdge()

        Metric {
            id: metricAlarms
            name: "clock-alarms"
            // Mark text for translation at a later point.
            // It will be translated by dtr (or dgettext) to allow plural forms
            format: i18n.tr("<b>%1</b> alarms today")
            emptyFormat: i18n.tr("No alarms today")
            domain: "lomiri-clock-app"
            minimum: 0.0
        }
    }

    // ========================== Handle URL Dispatcher calls =================================

    Arguments {
        id: args

        Argument {
            name: 'url'
            help: i18n.tr('Alarm search by URL')
            required: false
            valueNames: ['URL']
        }
    }

    Connections {
        target: UriHandler

        onOpened: {
            console.log('Open from UriHandler')

            if (uris.length > 0) {
                handleURLs(uris);
            }
        }
    }

    property var urlMapping: {
        "^alarm://" : mainPage.showAlarm,
        "^clock://" : mainPage.handleURLPage,
        "^stopwatch://" : mainPage.handleURLPage,
        "^timer://" : mainPage.handleURLPage
    }

    function handleURLs(urls) {
        if (urls && urls.length > 0) {
            for(var match in urlMapping) {
                for (var i = 0; i < urls.length; i++) {
                    if (urls[i].match(new RegExp(match))) {
                        console.log("forwarding URL : "+urls[i]);
                        urlMapping[match](urls[i]);
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        var arguments =  (Qt.application.arguments && Qt.application.arguments.length > 0) ?
                            Qt.application.arguments :
                            (args.values.url ? [args.values.url] : []);
        handleURLs(arguments);
    }
}
