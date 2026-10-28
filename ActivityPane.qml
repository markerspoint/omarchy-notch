import QtQuick
import qs.Commons
import qs.Commons as Commons

Item {
  id: pane
  property color foreground: Commons.Color.foreground
  property bool recording: false
  property string recordingTime: "0:00"
  property bool stopPending: false
  property string dictation: "idle"
  property int reminders: 0
  property bool stayAwake: false
  property bool dnd: false
  property bool idleAvailable: false
  property bool notificationsAvailable: false
  readonly property int rowHeight: Math.max(44, Math.ceil(Style.font.body * 3))
  readonly property var entries: [
    { icon: "󰻂", title: recording ? "Screen recording · " + recordingTime : "Screen recording", detail: recording ? "Recording is running" : "Choose a screen or region", button: recording ? (stopPending ? "Saving…" : "Stop & save") : "Record", action: "record", active: recording, enabled: !stopPending },
    { icon: "󰍬", title: "Dictation", detail: dictation === "recording" ? "Listening…" : dictation === "transcribing" ? "Transcribing…" : "Voice typing", button: dictation === "recording" ? "Stop" : "Settings", action: "dictation", active: dictation === "recording" || dictation === "transcribing", enabled: dictation !== "transcribing" },
    { icon: "󰃭", title: "Reminders", detail: reminders > 0 ? reminders + (reminders === 1 ? " reminder active" : " reminders active") : "No active reminders", button: "Open", action: "reminders", active: reminders > 0, enabled: true },
    { icon: "󰅶", title: "Stay awake", detail: stayAwake ? "Idle lock and screensaver paused" : "Using normal idle timers", button: stayAwake ? "Turn off" : "Turn on", action: "awake", active: stayAwake, enabled: idleAvailable },
    { icon: "󰂛", title: "Do Not Disturb", detail: dnd ? "Notifications silenced" : "Notifications allowed", button: dnd ? "Turn off" : "Turn on", action: "dnd", active: dnd, enabled: notificationsAvailable }
  ]
  implicitWidth: 440
  implicitHeight: entries.length * rowHeight + (entries.length - 1) * 8
  signal actionRequested(string action)

  Column {
    anchors.fill: parent
    spacing: 8
    Repeater {
      model: pane.entries
      delegate: Item {
        required property var modelData
        width: parent.width
        height: pane.rowHeight
        Text {
          id: icon
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: 26
          text: modelData.icon
          color: modelData.action === "record" && modelData.active ? "#ff7272" : pane.foreground
          opacity: modelData.active ? 1 : 0.6
          font.family: Style.font.family
          font.pixelSize: Style.font.iconLarge
        }
        Column {
          anchors.left: icon.right
          anchors.leftMargin: 10
          anchors.right: actionButton.left
          anchors.rightMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          spacing: 4
          Text {
            width: parent.width
            text: modelData.title
            color: pane.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: modelData.active
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: modelData.detail
            color: Commons.Util.alpha(pane.foreground, 0.6)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
        }
        Rectangle {
          id: actionButton
          width: Math.max(88, buttonLabel.implicitWidth + 24)
          height: 30
          radius: 15
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          color: Commons.Util.alpha(pane.foreground, buttonMouse.containsMouse ? 0.16 : 0.08)
          opacity: modelData.enabled ? 1 : 0.4
          Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: modelData.button
            color: pane.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
          MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: modelData.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: pane.actionRequested(modelData.action)
          }
        }
      }
    }
  }
}
