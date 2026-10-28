import QtQuick
import qs.Commons
import qs.Commons as Commons

// The toast pane, shared by the compact notification card and the big
// calendar card. A click anywhere runs the notification's default action.
Item {
  id: pane
  property color foreground: Commons.Color.foreground

  property string app: ""
  property string summary: ""
  property string body: ""
  property string image: ""
  property int iconSize: 44
  implicitWidth: Math.max(240, Math.min(488, iconSize + Style.space(12) + Math.max(summaryMeasure.implicitWidth, bodyMeasure.implicitWidth, appMeasure.implicitWidth)))
  implicitHeight: Math.max(iconSize,
    (app !== "" ? appText.implicitHeight : 0)
    + (summary !== "" ? summaryText.implicitHeight : 0)
    + (body !== "" ? bodyText.implicitHeight : 0)
    + Math.max(0, (app !== "" ? 1 : 0) + (summary !== "" ? 1 : 0) + (body !== "" ? 1 : 0) - 1) * Style.space(3))

  Text { id: summaryMeasure; visible: false; text: pane.summary; font.family: Style.font.family; font.pixelSize: Style.font.body + 1; font.bold: true }
  Text { id: bodyMeasure; visible: false; text: pane.body; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall }
  Text { id: appMeasure; visible: false; text: pane.app.toUpperCase(); font.family: Style.font.family; font.pixelSize: Style.font.caption - 1; font.letterSpacing: 0.8 }


  signal activated()

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: pane.activated()
  }

  Row {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(12)

    Rectangle {
      width: pane.iconSize
      height: pane.iconSize
      radius: Style.space(12)
      color: Commons.Util.alpha(pane.foreground, 0.08)

      Image {
        id: toastImage
        anchors.fill: parent
        anchors.margins: 1
        source: pane.image
        visible: source != ""
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(pane.iconSize * 2, pane.iconSize * 2)
      }

      Text {
        anchors.centerIn: parent
        visible: toastImage.source == "" || toastImage.status !== Image.Ready
        text: "󰂚"
        color: pane.foreground
        font.family: Style.font.family
        font.pixelSize: Math.round(pane.iconSize * 0.4)
      }
    }

    Column {
      id: toastDetails
      width: pane.width - pane.iconSize - Style.space(12)
      spacing: Style.space(3)

      Text {
        width: parent.width
        text: pane.app.toUpperCase()
        id: appText
        visible: text !== ""
        color: Commons.Util.alpha(pane.foreground, 0.70)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption - 1
        font.letterSpacing: 0.8
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }

      Text {
        width: parent.width
        text: pane.summary
        id: summaryText
        visible: text !== ""
        color: pane.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body + 1
        font.bold: true
        elide: Text.ElideRight
        maximumLineCount: 2
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
      }

      Text {
        width: parent.width
        text: pane.body
        id: bodyText
        visible: text !== ""
        color: Commons.Util.alpha(pane.foreground, 0.70)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
        maximumLineCount: 6
        elide: Text.ElideRight
        lineHeight: 1.15
        textFormat: Text.PlainText
      }
    }
  }
}
