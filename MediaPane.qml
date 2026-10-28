import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons

// One now-playing pane, shared by the compact hover card and the big
// calendar card. Sizes are owned by the parent; only the art diameter is
// passed in so the two layouts can breathe differently.
Item {
  id: pane
  property color foreground: Commons.Color.foreground

  property string title: ""
  property string artist: ""
  property string artUrl: ""
  property real length: 0
  property real shownPosition: 0
  property real progress: 0
  property bool playing: false
  property bool canPrev: false
  property bool canToggle: false
  property bool canNext: false
  property var spectrum: []
  property int artSize: 60
  property var videoSource: null
  property bool captureEnabled: true
  readonly property bool hasVideo: videoSource !== null
  readonly property bool videoReady: videoPreview.hasContent
  readonly property size videoSize: videoPreview.sourceSize
  readonly property int visualWidth: hasVideo ? 256 : artSize
  readonly property int visualHeight: hasVideo ? 144 : artSize
  implicitWidth: visualWidth + Style.space(14) + Math.max(180, Math.min(280, Math.max(titleMeasure.implicitWidth, artistMeasure.implicitWidth)))
  implicitHeight: Math.max(visualHeight, mediaDetails.implicitHeight)
  Text {
    id: titleMeasure
    visible: false
    text: pane.title
    font.family: Style.font.family
    font.pixelSize: Style.font.body + 2
    font.bold: true
  }
  Text {
    id: artistMeasure
    visible: false
    text: pane.artist
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
  }

  signal togglePlay()
  signal previous()
  signal next()

  function formatTime(seconds) {
    var value = Math.max(0, Math.floor(Number(seconds) || 0))
    var minutes = Math.floor(value / 60)
    var rest = value % 60
    return minutes + ":" + (rest < 10 ? "0" + rest : String(rest))
  }

  Row {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(14)

    Rectangle {
      width: pane.visualWidth
      height: pane.visualHeight
      radius: Style.space(14)
      color: Commons.Util.alpha(pane.foreground, 0.08)
      clip: true

      Rectangle {
        id: artworkMask
        anchors.fill: parent
        radius: Style.space(14)
        color: "white"
        visible: false
        layer.enabled: true
      }

      Image {
        id: artImage
        layer.enabled: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: artworkMask
        }
        anchors.fill: parent
        source: pane.artUrl
        visible: source != "" && !videoPreview.hasContent
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(pane.artSize * 2, pane.artSize * 2)
      }

      ScreencopyView {
        id: videoPreview
        anchors.centerIn: parent
        readonly property real aspect: sourceSize.width > 0 && sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 16 / 9
        width: Math.min(parent.width, parent.height * aspect)
        height: width / aspect
        captureSource: pane.captureEnabled && pane.visible ? pane.videoSource : null
        live: pane.captureEnabled && pane.visible && pane.hasVideo
        paintCursor: false
        constraintSize: Qt.size(pane.visualWidth * 2, pane.visualHeight * 2)
        layer.enabled: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: artworkMask
        }
      }

      Text {
        anchors.centerIn: parent
        visible: !videoPreview.hasContent && (artImage.source == "" || artImage.status !== Image.Ready)
        text: "󰝚"
        color: pane.foreground
        font.family: Style.font.family
        font.pixelSize: Math.round(pane.artSize * 0.4)
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: pane.togglePlay()
      }
    }

    Column {
      id: mediaDetails
      width: pane.width - pane.visualWidth - Style.space(14)
      spacing: Style.space(4)

      Text {
        width: parent.width
        text: pane.title !== "" ? pane.title : "Unknown track"
        color: pane.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body + 2
        font.bold: true
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }

      Text {
        width: parent.width
        text: pane.artist !== "" ? pane.artist : " "
        color: Commons.Util.alpha(pane.foreground, 0.70)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        textFormat: Text.PlainText
      }

      Item {
        id: spectrumArea
        width: parent.width
        height: Style.space(28)

        Row {
          anchors.fill: parent
          spacing: 2
          Repeater {
            model: 32
            delegate: Rectangle {
              required property int index
              readonly property real amplitude: pane.playing && pane.spectrum.length === 32 ? pane.spectrum[index] : 0
              width: Math.max(1, (spectrumArea.width - 31 * 2) / 32)
              height: Math.max(2, amplitude * spectrumArea.height)
              y: spectrumArea.height - height
              radius: width / 2
              color: pane.foreground
              opacity: 0.30 + 0.65 * amplitude
              Behavior on height { NumberAnimation { duration: 65; easing.type: Easing.OutQuad } }
              Behavior on opacity { NumberAnimation { duration: 65 } }
            }
          }
        }
      }

      Item {
        width: parent.width
        height: Style.space(10)

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: 3
          radius: 1.5
          color: Commons.Util.alpha(pane.foreground, 0.16)

          Rectangle {
            width: parent.width * Math.max(0, Math.min(1, pane.progress))
            height: parent.height
            radius: parent.radius
            color: pane.foreground
            Behavior on width { NumberAnimation { duration: 200 } }
          }
        }
      }

      Row {
        id: bottomRow
        width: parent.width
        spacing: Style.space(4)

        Text {
          id: timeText
          text: pane.length > 0
            ? pane.formatTime(pane.shownPosition) + " / " + pane.formatTime(pane.length)
            : ""
          color: Commons.Util.alpha(pane.foreground, 0.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption - 1
          anchors.verticalCenter: parent.verticalCenter
        }

        Item {
          width: Math.max(0, parent.width - timeText.implicitWidth - 3 * Style.space(26) - 2 * parent.spacing)
          height: 1
        }

        Repeater {
          model: [
            { glyph: "󰒮", action: "prev", enabled: pane.canPrev },
            { glyph: pane.playing ? "󰏤" : "󰐊", action: "playPause", enabled: pane.canToggle },
            { glyph: "󰒭", action: "next", enabled: pane.canNext }
          ]

          delegate: Text {
            required property var modelData
            text: modelData.glyph
            color: modelData.enabled ? pane.foreground : Commons.Util.alpha(pane.foreground, 0.25)
            font.family: Style.font.family
            font.pixelSize: Style.font.iconLarge
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(26)
            horizontalAlignment: Text.AlignHCenter

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              enabled: modelData.enabled
              onClicked: {
                if (modelData.action === "prev") pane.previous()
                else if (modelData.action === "next") pane.next()
                else pane.togglePlay()
              }
            }
          }
        }
      }
    }
  }
}
