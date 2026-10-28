import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons

// Compact read-out month grid for the notch: month header with step
// chevrons, ISO weekdays, today marked, and the current ISO week + year
// progress in the footer. Built to sit in the right half of the big card.
Item {
  id: cal
  property color foreground: Commons.Color.foreground

  implicitWidth: 214
  implicitHeight: 184

  property date now: new Date()
  property date view: new Date(now.getFullYear(), now.getMonth(), 1)

  readonly property var cells: buildCells(view, now)
  readonly property real cellWidth: width / 7
  readonly property real cellHeight: 21

  function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear()
      && a.getMonth() === b.getMonth()
      && a.getDate() === b.getDate()
  }

  function buildCells(anchor, today) {
    var first = new Date(anchor.getFullYear(), anchor.getMonth(), 1)
    var offset = (first.getDay() + 6) % 7
    var start = new Date(first.getFullYear(), first.getMonth(), 1 - offset)
    var out = []
    for (var i = 0; i < 42; i++) {
      var d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
      out.push({
        day: d.getDate(),
        inMonth: d.getMonth() === anchor.getMonth(),
        today: sameDay(d, today)
      })
    }
    return out
  }

  function cellAt(index) {
    return cells[index] || { day: "", inMonth: false, today: false }
  }

  function isoWeek(date) {
    var d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()))
    var dayNum = d.getUTCDay() || 7
    d.setUTCDate(d.getUTCDate() + 4 - dayNum)
    var yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
    return Math.ceil((((d - yearStart) / 86400000) + 1) / 7)
  }

  function yearPercent(date) {
    var start = new Date(date.getFullYear(), 0, 1)
    var end = new Date(date.getFullYear() + 1, 0, 1)
    return Math.round((date - start) / (end - start) * 100)
  }

  function step(delta) {
    view = new Date(view.getFullYear(), view.getMonth() + delta, 1)
  }

  function goToday() {
    now = new Date()
    view = new Date(now.getFullYear(), now.getMonth(), 1)
  }

  SystemClock {
    precision: SystemClock.Minutes
    onDateChanged: cal.now = date
  }

  function debugState() {
    return JSON.stringify({
      paneHeight: Math.round(height),
      columnHeight: Math.round(column.height),
      gridHeight: Math.round(grid.height),
      footerY: Math.round(footer.y),
      cellHeight: cellHeight
    })
  }

  Column {
    id: column
    anchors.fill: parent

    Item {
      width: parent.width
      height: 22

      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Text {
          id: monthText
          text: Qt.formatDateTime(cal.view, "MMMM")
          color: cal.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title + 2
          font.bold: true
        }

        Text {
          id: yearText
          text: cal.view.getFullYear()
          color: Commons.Util.alpha(cal.foreground, 0.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption - 1
          anchors.baseline: monthText.baseline
        }
      }

      Item {
        width: 18
        height: parent.height
        anchors.right: nextArrow.left
        anchors.rightMargin: 2

        Text {
          anchors.centerIn: parent
          text: "‹"
          color: prevArea.containsMouse ? cal.foreground : Commons.Util.alpha(cal.foreground, 0.55)
          font.family: Style.font.family
          font.pixelSize: 17
        }

        MouseArea {
          id: prevArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: cal.step(-1)
        }
      }

      Item {
        id: nextArrow
        width: 18
        height: parent.height
        anchors.right: parent.right

        Text {
          anchors.centerIn: parent
          text: "›"
          color: nextArea.containsMouse ? cal.foreground : Commons.Util.alpha(cal.foreground, 0.55)
          font.family: Style.font.family
          font.pixelSize: 17
        }

        MouseArea {
          id: nextArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: cal.step(1)
        }
      }
    }

    Item { width: 1; height: 5 }

    Row {
      width: parent.width

      Repeater {
        model: ["M", "T", "W", "T", "F", "S", "S"]

        delegate: Text {
          required property string modelData
          width: cal.cellWidth
          height: 10
          text: modelData
          color: Commons.Util.alpha(cal.foreground, 0.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption - 1
          font.letterSpacing: 0.5
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }
    }

    Item { width: 1; height: 4 }

    Grid {
      id: grid
      columns: 7

      Repeater {
        model: 42

        delegate: Item {
          required property int index
          width: cal.cellWidth
          height: cal.cellHeight

          Rectangle {
            anchors.centerIn: parent
            width: 17
            height: 17
            radius: 8.5
            color: cal.cellAt(index).today ? cal.foreground : "transparent"
          }

          Text {
            anchors.centerIn: parent
            text: cal.cellAt(index).day
            color: cal.cellAt(index).today ? Commons.Color.background : cal.foreground
            opacity: cal.cellAt(index).inMonth ? 1 : 0.25
            font.family: Style.font.family
            font.pixelSize: Style.font.caption - 1
          }
        }
      }
    }

    Item { width: 1; height: 6 }

    Item {
      id: footer
      width: parent.width
      height: 11

      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "Week " + cal.isoWeek(cal.now)
        color: Commons.Util.alpha(cal.foreground, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption - 1
      }

      Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: cal.yearPercent(cal.now) + "% of " + cal.now.getFullYear()
        color: Commons.Util.alpha(cal.foreground, 0.40)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption - 1
      }
    }
  }
}
