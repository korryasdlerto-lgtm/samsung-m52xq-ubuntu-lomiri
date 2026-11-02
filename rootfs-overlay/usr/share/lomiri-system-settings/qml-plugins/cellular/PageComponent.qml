/* m52xq (убунтутач24/003): Cellular page for ModemManager / NetworkManager (settings:///system/cellular from the shade) */
import QtQuick 2.12
import SystemSettings 1.0
import SystemSettings.ListItems 1.0 as SettingsListItems
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItems
import Lomiri.Components.Popups 1.3
import Lomiri.SystemSettings.M52xqCellular 1.0

ItemPage {
    id: root
    objectName: "cellularPage"
    title: i18n.tr("Cellular")
    flickable: flick

    property var st: ({})
    property var simList: []
    property bool busy: false

    M52xqMobile {
        id: mobile
    }

    function refresh() {
        st = mobile.status();
        simList = mobile.sims();
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 3000
        running: root.visible
        repeat: true
        onTriggered: if (!root.busy) root.refresh()
    }

    /* the data switch / SIM change take a few seconds: do not let the poll flip the control back meanwhile */
    Timer {
        id: settle
        interval: 6000
        onTriggered: { root.busy = false; root.refresh(); }
    }
    function hold() { busy = true; settle.restart(); }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: parent.width
        contentHeight: column.height + units.gu(2)
        boundsBehavior: contentHeight > root.height ? Flickable.DragAndOvershootBounds : Flickable.StopAtBounds

        Column {
            id: column
            anchors { left: parent.left; right: parent.right }

            SettingsListItems.Standard {
                text: i18n.tr("Cellular data")
                enabled: !!root.st.connection && !root.st.flight
                onClicked: dataSwitch.trigger()

                Switch {
                    id: dataSwitch
                    checked: !!root.st.dataOn
                    enabled: parent.enabled
                    onTriggered: {
                        root.hold();
                        mobile.setDataEnabled(checked);
                    }
                }
            }

            SettingsListItems.Standard {
                text: i18n.tr("Data roaming")
                enabled: !!root.st.connection
                onClicked: roamSwitch.trigger()

                Switch {
                    id: roamSwitch
                    checked: !!root.st.roaming
                    enabled: parent.enabled
                    onTriggered: { mobile.setRoaming(checked); root.hold(); }
                }
            }

            ListItems.Caption {
                text: i18n.tr("When roaming is off, cellular data works only in the home network.")
            }

            SettingsListItems.Standard {
                text: i18n.tr("Data SIM")
                visible: root.st.mode === "dsds" && root.simList.length > 1
                enabled: !root.st.flight

                Row {
                    spacing: units.gu(1)
                    anchors.verticalCenter: parent.verticalCenter

                    Button {
                        text: "SIM 1"
                        color: root.st.dataSim === 1 ? theme.palette.normal.positive : theme.palette.normal.base
                        onClicked: { if (root.st.dataSim !== 1) { root.hold(); mobile.setDataSim(1); } }
                    }
                    Button {
                        text: "SIM 2"
                        color: root.st.dataSim === 2 ? theme.palette.normal.positive : theme.palette.normal.base
                        onClicked: { if (root.st.dataSim !== 2) { root.hold(); mobile.setDataSim(2); } }
                    }
                }
            }

            ListItems.Caption {
                visible: root.st.mode === "dsds" && root.simList.length > 1
                text: i18n.tr("Only one SIM carries mobile data at a time. Switching takes about half a minute while the modem restarts.")
            }

            ListItems.Caption {
                visible: root.st.mode !== "dsds"
                text: root.st.mode === "sim1" ? i18n.tr("Only SIM 1 is active, data goes through it.")
                                                : i18n.tr("Only SIM 2 is active, data goes through it.")
            }

            ListItems.Caption {
                visible: !!root.st.flight
                text: i18n.tr("SIM cards are turned off (flight mode).")
            }

            ListItems.Header {
                text: i18n.tr("SIM cards")
            }

            Repeater {
                model: root.simList
                SettingsListItems.Standard {
                    text: "SIM " + modelData.slot
                    layout.subtitle.text: (modelData.operator ? modelData.operator + ", " : "") +
                                           (modelData.state || "") +
                                           (modelData.signal !== undefined ? ", " + modelData.signal + "%" : "") +
                                           (modelData.tech ? ", " + modelData.tech : "")
                }
            }

            ListItems.Header {
                text: i18n.tr("Access point name (APN)")
                visible: !!root.st.connection
            }

            Item {
                visible: !!root.st.connection
                width: parent.width
                height: apnField.height + units.gu(3)

                TextField {
                    id: apnField
                    anchors { left: parent.left; right: applyButton.left; margins: units.gu(2); verticalCenter: parent.verticalCenter }
                    placeholderText: i18n.tr("internet")
                    text: root.st.apn || ""
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhUrlCharactersOnly
                }
                Button {
                    id: applyButton
                    anchors { right: parent.right; rightMargin: units.gu(2); verticalCenter: parent.verticalCenter }
                    text: i18n.tr("Apply")
                    onClicked: { if (mobile.setApn(apnField.text)) root.hold(); }
                }
            }

            ListItems.Caption {
                visible: !!root.st.connection
                text: i18n.tr("A new APN applies the next time cellular data is turned on.")
            }
        }
    }
}
