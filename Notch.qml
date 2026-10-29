import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import qs.Commons
import qs.Commons as Commons

// Theme-aware screen-edge notch attached beneath the clock. Click the clock/date (or
// the island itself) to open a tabbed music and calendar panel with a
// now-playing pane and a month calendar. Notifications use the same island
// and auto-expand it; hovering the collapsed pill peeks at the current track.
//
// Media is read from MPRIS directly. Notifications are read from the per-toast
// JSON files Omarchy writes while a toast is live; with takeOverNativeToasts
// the native top-right toast is dismissed so the notch is the only place it
// appears. The overlay sits on the wlr overlay layer and is click-through
// everywhere except the island and the clock strip above it.
Item {
  id: root

  property var shell: null
  property var manifest: null

  // ---------------------------------------------------------------- tuning
  readonly property bool liquidGlassEnabled: true
  property url wallpaperImageSource: ""
  property string wallpaperRevision: ""
  property real glassLightX: 0.25
  property real glassLightY: 0.15
  Behavior on glassLightX { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
  Behavior on glassLightY { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
  readonly property int collapsedWidth: 164
  readonly property int collapsedHeight: 10
  readonly property int compactWidth: 420
  readonly property int compactHeight: 138
  readonly property int pinnedWidth: activitySelected ? Math.min(availableWidth, 440) : Math.min(availableWidth, Math.ceil((hasMedia ? mediaMeasure.implicitWidth : 220) + (calendarSelected ? 214 : 150) + 67))
  readonly property int pinnedHeight: activitySelected ? Math.ceil(54 + activityPane.implicitHeight + Style.space(16)) : Math.ceil(54 + Math.max(hasMedia ? mediaMeasure.implicitHeight : 60, calendarSelected ? calendarPane.implicitHeight : actionsColumn.implicitHeight) + Style.space(16))
  // Match only the centered clock label, keeping neighboring bar controls clickable.
  readonly property int clockHitWidth: Math.ceil(clockLabelMetrics.width)
  readonly property string clockFormat: {
    var entries = root.shell && root.shell.barConfig && root.shell.barConfig.layout
      ? (root.shell.barConfig.layout.center || []) : []
    for (var i = 0; i < entries.length; i++)
      if (entries[i].id === "omarchy.clock") return String(entries[i].format || "dddd HH:mm")
    return "dddd HH:mm"
  }
  SystemClock { id: notchClock; precision: SystemClock.Minutes }
  TextMetrics {
    id: clockLabelMetrics
    text: Qt.formatDateTime(notchClock.date, root.clockFormat.replace(/ww/g, "00"))
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }
  readonly property int toastSeconds: 6
  readonly property int trackChangeSeconds: 4
  // Dismiss Omarchy's own toast as soon as the notch picks it up.
  readonly property bool takeOverNativeToasts: true
  // Pop the compact card open when the track changes.
  readonly property bool flashOnTrackChange: true
  // Keep the slim pill on screen even with nothing playing.
  readonly property bool alwaysVisible: true

  // -------------------------------------------------------------- geometry
  readonly property int barSize: root.shell && root.shell.bar
    ? Math.max(0, Number(root.shell.bar.barSize) || 0) : 0
  readonly property string barPosition: root.shell && root.shell.bar
    ? String(root.shell.bar.position || "top") : "top"
  // Fullscreen hides top-layer bars without changing their barHidden flag.
  // Follow the workspace on the notch's own monitor, not merely the active app.
  readonly property var targetMonitor: root.targetScreen ? Hyprland.monitorFor(root.targetScreen) : null
  readonly property bool fullscreenOnScreen: !!(targetMonitor && targetMonitor.activeWorkspace
    && targetMonitor.activeWorkspace.hasFullscreen)
  readonly property bool barVisible: !fullscreenOnScreen
    && (root.shell && root.shell.bar ? !root.shell.bar.barHidden : true)
  // Join directly to the bottom of the bar while keeping its clock readable.
  readonly property int topOffset: (barPosition === "top" && barVisible)
    ? (barSize > 0 ? barSize : Style.bar.sizeHorizontal) : 0
  readonly property int clockX: Math.round((window.width - clockHitWidth) / 2)

  readonly property var targetScreen: {
    var screens = Quickshell.screens || []
    var monitor = Hyprland.focusedMonitor
    if (monitor) {
      for (var i = 0; i < screens.length; i++)
        if (screens[i].name === monitor.name) return screens[i]
    }
    return screens.length > 0 ? screens[0] : null
  }

  // Follow the bar's theme surface; transparent bars show the wallpaper.
  readonly property bool transparentBar: root.shell && root.shell.barConfig
    ? root.shell.barConfig.transparent === true : false
  property color wallpaperBarColor: Commons.Color.background
  // The compositor supplies the frosted backdrop; this is only its tint.
  readonly property color surfaceColor: transparentBar
    ? Commons.Util.alpha(wallpaperBarColor, 1 / 255)
    : Commons.Color.bar.background
  readonly property int availableWidth: Math.max(280, (targetScreen ? targetScreen.width : 1920) - 48)
  function luminance(color) {
    function linear(value) { return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
  }
  function contrast(a, b) {
    var first = luminance(a), second = luminance(b)
    return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05)
  }
  readonly property color surfaceForeground: transparentBar
    ? (contrast(Commons.Color.bar.text, wallpaperBarColor) >= contrast(Commons.Color.background, wallpaperBarColor)
      ? Commons.Color.bar.text : Commons.Color.background)
    : Commons.Color.bar.text

  Process {
    command: ["bash", Qt.resolvedUrl("watch-navbar.sh").toString().replace(/^file:\/\//, ""),
      String(root.targetScreen ? root.targetScreen.width : 1920),
      String(root.targetScreen ? root.targetScreen.height : 1080),
      String(Math.max(1, root.topOffset)), "620"]
    running: true
    stdout: SplitParser {
      onRead: data => {
        try {
          var value = JSON.parse(data)
          if (/^#[0-9a-fA-F]{6}$/.test(value.color)) root.wallpaperBarColor = value.color
          if (value.revision !== root.wallpaperRevision) {
            root.wallpaperRevision = value.revision
            root.wallpaperImageSource = ""
            var source = Commons.Util.fileUrl(value.path)
            Qt.callLater(function() { root.wallpaperImageSource = source })
          }
        } catch (e) {}
      }
    }
  }

  // ----------------------------------------------------------------- media
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: {
    var list = root.players || []
    var playing = null
    var candidate = null
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      if (!p) continue
      if (!p.trackTitle && !p.trackArtist && !p.trackAlbum && !p.trackArtUrl) continue
      if (p.isPlaying) { playing = p; break }
      if (!candidate) candidate = p
    }
    return playing || candidate
  }
  readonly property bool hasMedia: !!player && !!(player.trackTitle || player.trackArtist)
  readonly property bool playing: !!player && player.isPlaying === true
  readonly property string trackTitle: player ? String(player.trackTitle || "") : ""
  readonly property string trackArtist: player ? String(player.trackArtist || "") : ""
  readonly property string trackArt: player ? String(player.trackArtUrl || "") : ""
  readonly property real trackLength: player ? Math.max(0, Number(player.length) || 0) : 0

  // Only mirror a dedicated PiP surface belonging to the active media browser.
  // Never capture arbitrary browser tabs or another application's windows.
  readonly property var videoSource: {
    if (!root.hasMedia || !root.player) return null
    var identity = String(root.player.desktopEntry || root.player.identity || "").toLowerCase()
    var family = identity.indexOf("brave") >= 0 ? "brave"
      : identity.indexOf("firefox") >= 0 ? "firefox"
      : identity.indexOf("chromium") >= 0 ? "chromium"
      : identity.indexOf("chrome") >= 0 ? "chrome"
      : identity.indexOf("edge") >= 0 ? "edge" : ""
    if (!family) return null
    var windows = ToplevelManager.toplevels.values || []
    var matches = []
    for (var i = 0; i < windows.length; i++) {
      var candidate = windows[i]
      var app = String(candidate.appId || "").toLowerCase()
      var title = String(candidate.title || "")
      if (app.indexOf(family) < 0) continue
      if (!/^picture[ -]in[ -]picture(?:$|[ \u2014-])/i.test(title)) continue
      matches.push(candidate)
    }
    return matches.length === 1 ? matches[0] : null
  }

  property real shownPosition: 0
  property string lastTrackKey: ""
  property bool lastMediaPlaying: false

  readonly property real progress: trackLength > 0
    ? Math.max(0, Math.min(1, shownPosition / trackLength)) : 0

  function syncPosition() {
    var value = root.player ? Number(root.player.position) : 0
    root.shownPosition = isFinite(value) && value > 0 ? value : 0
  }

  function togglePlay() {
    if (root.player && (root.player.canTogglePlaying || root.player.canPlay || root.player.canPause))
      root.player.togglePlaying()
  }
  function nextTrack() { if (root.player && root.player.canGoNext) root.player.next() }
  function previousTrack() { if (root.player && root.player.canGoPrevious) root.player.previous() }

  // MPRIS can update player, title, artist, and playback separately. Coalesce
  // them before choosing a tab so switching players cannot consume the event.
  onPlayerChanged: mediaStateUpdate.restart()
  onTrackTitleChanged: mediaStateUpdate.restart()
  onTrackArtistChanged: mediaStateUpdate.restart()
  onPlayingChanged: mediaStateUpdate.restart()

  Timer {
    id: mediaStateUpdate
    interval: 50
    onTriggered: root.trackChanged()
  }

  function trackChanged() {
    var key = root.player
      ? String(root.player.dbusName || "") + "\n" + root.trackTitle + "\n" + root.trackArtist
      : ""
    var newPlayback = root.hasMedia && root.playing
      && (key !== root.lastTrackKey || !root.lastMediaPlaying)
    root.lastTrackKey = key
    root.lastMediaPlaying = root.playing
    syncPosition()
    if (!newPlayback) return
    root.activitySelected = false
    root.calendarSelected = false
    if (flashOnTrackChange && !root.expanded) flash()
  }

  Timer {
    interval: 500
    running: true
    repeat: true
    onTriggered: {
      if (!root.playing) return
      if (root.trackLength > 0) root.shownPosition = Math.min(root.trackLength, root.shownPosition + 0.5)
      var actual = root.player ? Number(root.player.position) : 0
      if (isFinite(actual) && actual > 0 && Math.abs(actual - root.shownPosition) > 4) root.shownPosition = actual
    }
  }

  // Cava analyzes the default output monitor; one process serves the visible pane.
  readonly property bool visualizerActive: root.expanded && !root.notificationView && !root.activitySelected && root.hasMedia && root.playing
  property var audioLevels: []
  property int audioFrames: 0
  onVisualizerActiveChanged: if (!visualizerActive) audioLevels = []

  Process {
    id: audioAnalyzer
    command: ["cava", "-p", Qt.resolvedUrl("cava.conf").toString().replace(/^file:\/\//, "")]
    running: root.visualizerActive
    stdout: SplitParser {
      onRead: data => {
        var values = data.trim().split(";")
        if (values.length > 0 && values[values.length - 1] === "") values.pop()
        if (values.length !== 32) return
        var levels = []
        for (var i = 0; i < values.length; i++) {
          var value = Number(values[i])
          if (!isFinite(value)) return
          levels.push(Math.max(0, Math.min(1, value / 100)))
        }
        root.audioLevels = levels
        root.audioFrames++
      }
    }
  }

  // Persistent desktop activities, using the same state sources as the bar.
  property bool screenRecording: false
  property int recordingSeconds: 0
  property bool stopRecordingPending: false
  property string dictationState: "idle"
  property int reminderCount: 0
  property bool stayAwake: false
  property bool dnd: false
  readonly property bool dictating: dictationState === "recording" || dictationState === "transcribing"
  readonly property int activeActivityCount: (screenRecording ? 1 : 0) + (dictating ? 1 : 0)
    + (reminderCount > 0 ? 1 : 0) + (stayAwake ? 1 : 0) + (dnd ? 1 : 0)
  readonly property bool hasActivities: activeActivityCount > 0
  readonly property string recordingTime: Math.floor(recordingSeconds / 60) + ":" + (recordingSeconds % 60 < 10 ? "0" : "") + recordingSeconds % 60
  readonly property string activityLabel: screenRecording ? "Recording · " + recordingTime
    : dictating ? (dictationState === "recording" ? "Listening…" : "Transcribing…")
    : reminderCount > 0 ? reminderCount + (reminderCount === 1 ? " reminder" : " reminders")
    : stayAwake ? "Stay awake" : "Do Not Disturb"

  onScreenRecordingChanged: {
    if (screenRecording) { activitySelected = true; flash() }
    else stopRecordingPending = false
  }

  function stopRecording() {
    if (!screenRecording || stopRecordingPending) return
    stopRecordingPending = true
    stopRecordProc.running = true
  }
  function activityAction(action) {
    if (action === "record") {
      if (screenRecording) stopRecording()
      else { closeAll(); Quickshell.execDetached(["omarchy-menu", "toggle", "trigger.capture.screenrecord"]) }
    } else if (action === "dictation") {
      if (dictationState === "recording") Quickshell.execDetached(["voxtype", "record", "stop"])
      else { closeAll(); Quickshell.execDetached(["omarchy-voxtype-config"]) }
    } else if (action === "reminders") {
      closeAll(); Quickshell.execDetached(["omarchy-reminder", "-i"])
    } else if (action === "awake") Quickshell.execDetached(["omarchy-shell", "idle", "toggle"])
    else if (action === "dnd") Quickshell.execDetached(["omarchy-shell", "notifications", "toggleDnd"])
  }

  Process {
    command: ["python", Qt.resolvedUrl("watch-recording.py").toString().replace(/^file:\/\//, "")]
    running: true
    stdout: SplitParser {
      onRead: data => {
        try {
          var state = JSON.parse(data)
          root.recordingSeconds = Math.max(0, Number(state.seconds) || 0)
          root.screenRecording = state.recording === true
          root.stayAwake = state.stay_awake === true
          if (typeof state.dnd === "boolean") root.dnd = state.dnd
        } catch (e) {}
      }
    }
  }
  Process {
    id: stopRecordProc
    command: ["omarchy-capture-screenrecording", "--stop-recording"]
    onExited: root.stopRecordingPending = false
  }
  Process {
    command: ["omarchy-voxtype-status"]
    running: true
    stdout: SplitParser {
      onRead: data => {
        try {
          var state = JSON.parse(data)
          var previous = root.dictationState
          root.dictationState = String(state.alt || state.class || "idle")
          if (root.dictationState === "recording" && previous !== "recording") {
            root.activitySelected = true; root.flash()
          }
        } catch (e) {}
      }
    }
  }
  Process {
    id: reminderReader
    command: ["omarchy-reminder", "show", "--json"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.reminderCount = Math.max(0, Number(JSON.parse(text).count) || 0) }
        catch (e) { root.reminderCount = 0 }
      }
    }
  }
  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: if (!reminderReader.running) reminderReader.running = true
  }

  // ---------------------------------------------------------- notifications
  readonly property string notificationsDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/omarchy/notifications"

  property var liveNotifications: []
  property var seenToasts: ({})
  property bool notificationsPrimed: false
  property var toast: null
  property bool toastActive: false

  readonly property bool showToastCard: toastActive && toast !== null
  readonly property bool toastHasBody: toast !== null && String(toast.body || "") !== ""

  function toastField(key) {
    return root.toast ? String(root.toast[key] || "") : ""
  }

  function refreshNotifications() {
    if (!notifyReader.running) notifyReader.running = true
  }

  function toastKey(entry) {
    if (!entry) return ""
    return String(entry.id) + ":" + String(entry.timestamp)
  }

  function handleNotifications(raw) {
    var list = []
    try { list = JSON.parse(raw || "[]") } catch (e) { list = [] }
    if (!Array.isArray(list)) list = []

    if (!root.notificationsPrimed) {
      root.notificationsPrimed = true
      var seen = {}
      for (var s = 0; s < list.length; s++) seen[toastKey(list[s])] = true
      root.seenToasts = seen
      return
    }

    var fresh = []
    var nextSeen = {}
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      var k = toastKey(entry)
      nextSeen[k] = true
      if (!root.seenToasts[k]) fresh.push(entry)
    }
    root.seenToasts = nextSeen
    if (fresh.length === 0) return

    var newest = fresh[0]
    for (var f = 1; f < fresh.length; f++)
      if (Number(fresh[f].timestamp) > Number(newest.timestamp)) newest = fresh[f]

    root.showToast(newest)
  }

  function showToast(entry) {
    root.toast = entry
    root.toastActive = true
    toastTimer.restart()
    if (root.takeOverNativeToasts && entry && entry.summary)
      dismissNative(String(entry.summary))
  }

  function dismissNative(summary) {
    dismissProc.command = ["omarchy-shell", "-q", "notifications", "dismiss", summary]
    dismissProc.running = true
  }

  function invokeToast() {
    var entry = root.toast
    root.toastActive = false
    root.toast = null
    if (!entry) return
    var argv = []
    try { argv = JSON.parse(entry.execArgv || "[]") } catch (e) { argv = [] }
    if (Array.isArray(argv) && argv.length > 0) Quickshell.execDetached(argv)
  }

  Process {
    id: notifyReader
    command: ["bash", Qt.resolvedUrl("watch-notifications.sh").toString().replace(/^file:\/\//, "")]
    stdout: StdioCollector {
      onStreamFinished: root.handleNotifications(text)
    }
  }

  Process { id: dismissProc }

  Process {
    id: clockCycleProc
    command: ["omarchy-shell", "-q", "omarchy.clock", "cycleFormat"]
  }

  FileView {
    path: root.notificationsDir
    watchChanges: true
    printErrors: false
    onFileChanged: notifyRefresh.restart()
  }

  Timer {
    id: notifyRefresh
    interval: 120
    onTriggered: root.refreshNotifications()
  }

  // Backstop for anything the directory watcher misses.
  Timer {
    interval: 2500
    running: true
    repeat: true
    onTriggered: root.refreshNotifications()
  }

  Timer {
    id: toastTimer
    interval: root.toastSeconds * 1000
    onTriggered: {
      root.toastActive = false
      root.toast = null
    }
  }

  // ------------------------------------------------------------ open state
  property bool hovered: false
  property bool pinned: false
  property bool calendarSelected: true
  property bool activitySelected: false
  property bool flashing: false

  readonly property bool expanded: pinned || hovered || toastActive || flashing
  readonly property bool compact: expanded && !pinned
  readonly property bool idleHidden: !alwaysVisible && !expanded && !hasMedia

  readonly property bool notificationView: expanded && showToastCard
  readonly property int cardWidth: !expanded ? (hasActivities ? 252 : collapsedWidth)
    : (notificationView ? Math.min(availableWidth, Math.ceil(toastMeasure.implicitWidth + 32)) : pinnedWidth)
  readonly property int cardHeight: !expanded ? (hasActivities ? 32 : collapsedHeight)
    : (notificationView ? Math.ceil(toastMeasure.implicitHeight + 28) : pinnedHeight)

  readonly property int cardY: topOffset

  Timer {
    id: hoverExitTimer
    interval: 220
    onTriggered: root.hovered = false
  }

  function flash() { flashing = true; flashTimer.restart() }
  function pin() { pinned = true }
  function unpin() { pinned = false }

  function closeAll() {
    hoverExitTimer.stop()
    pinned = false
    hovered = false
    flashing = false
    toastActive = false
    toast = null
  }

  onPinnedChanged: {
    if (pinned) {
      calendarPane.goToday()
      refreshNotifications()
    }
  }

  Timer {
    id: flashTimer
    interval: root.trackChangeSeconds * 1000
    onTriggered: root.flashing = false
  }

  function open() { pin() }
  function close() { closeAll() }

  Component.onCompleted: refreshNotifications()

  // ------------------------------------------------------------------- UI
  PanelWindow {
    id: window
    screen: root.targetScreen

    anchors {
      top: true
      left: true
      right: true
      bottom: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "mark-notch"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  // Separate measurement items keep animation geometry out of size calculations.
  MediaPane {
    id: mediaMeasure
    videoSource: root.videoSource
    captureEnabled: false
    opacity: 0
    enabled: false
    artSize: 88
    title: root.trackTitle
    artist: root.trackArtist
    width: implicitWidth
  }
  ToastPane {
    id: toastMeasure
    opacity: 0
    enabled: false
    iconSize: 44
    app: root.toastField("app")
    summary: root.toastField("summary")
    body: root.toastField("body")
    width: Math.min(root.availableWidth - 32, implicitWidth)
  }

    // Only the date label intercepts bar clicks. Everything else on the
    // top bar (including the recording indicator) belongs to the native bar.
    mask: Region {
      item: maskRegion
      Region {
        x: root.clockX
        y: 0
        width: root.clockHitWidth
        height: root.topOffset
      }
    }

    Item {
      id: maskRegion
      x: root.pinned ? 0 : pill.x
      y: root.pinned ? root.topOffset : pill.y
      width: root.pinned ? window.width : (root.idleHidden ? 0 : pill.width)
      height: root.pinned ? Math.max(0, window.height - root.topOffset)
        : (root.idleHidden ? 0 : pill.height)
    }

    // Click-away: only mapped while pinned, and sits below the card.
    MouseArea {
      anchors.fill: parent
      visible: root.pinned
      onClicked: root.unpin()
    }

    Item {
      id: pill
      x: Math.round((parent.width - width) / 2)
      y: root.cardY
      width: root.cardWidth
      height: root.cardHeight
      opacity: root.idleHidden ? 0 : 1
      visible: opacity > 0

      // Snap to the visible screen/bar edge; animating this creates a floating seam.
      Behavior on width { NumberAnimation { duration: 340; easing.type: Easing.OutQuint } }
      Behavior on height { NumberAnimation { duration: 340; easing.type: Easing.OutQuint } }
      Behavior on opacity { NumberAnimation { duration: 160 } }

      // One outline avoids hairline seams between shoulders and body.
      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real shoulder: Math.min(12, height / 2)
        readonly property real corner: Math.min(root.expanded ? 26 : 10, height / 2)
        ShapePath {
          fillColor: root.surfaceColor
          strokeColor: "transparent"
          startX: -12; startY: -1
          PathQuad { x: 0; y: Math.min(12, pill.height / 2); controlX: 0; controlY: -1 }
          PathLine { x: 0; y: pill.height - Math.min(root.expanded ? 26 : 10, pill.height / 2) }
          PathQuad {
            x: Math.min(root.expanded ? 26 : 10, pill.height / 2); y: pill.height
            controlX: 0; controlY: pill.height
          }
          PathLine { x: pill.width - Math.min(root.expanded ? 26 : 10, pill.height / 2); y: pill.height }
          PathQuad { x: pill.width; y: pill.height - Math.min(root.expanded ? 26 : 10, pill.height / 2); controlX: pill.width; controlY: pill.height }
          PathLine { x: pill.width; y: Math.min(12, pill.height / 2) }
          PathQuad { x: pill.width + 12; y: -1; controlX: pill.width; controlY: -1 }
          PathLine { x: -12; y: -1 }
        }
      }

      LiquidGlass {
        id: liquidGlass
        anchors.fill: parent
        visible: root.liquidGlassEnabled && root.transparentBar && root.expanded
        wallpaperSource: visible ? root.wallpaperImageSource : ""
        screenWidth: window.width
        screenHeight: window.height
        sceneX: pill.x
        sceneY: pill.y
        cornerRadius: root.expanded ? 26 : 10
        lightX: root.glassLightX
        lightY: root.glassLightY
        opacity: root.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
      }

      Rectangle {
        id: shell
        anchors.fill: parent
        color: "transparent"
        border.width: 0
        clip: true

        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: root.expanded ? 26 : 10
        bottomRightRadius: root.expanded ? 26 : 10

        // Clicking the island background opens the big card; while pinned the
        // same area absorbs clicks so the calendar does not close it.
        MouseArea {
          anchors.fill: parent
          cursorShape: root.pinned ? Qt.ArrowCursor : Qt.PointingHandCursor
          onClicked: {
            if (!root.pinned) root.pin()
          }
        }

        Row {
          anchors.centerIn: parent
          spacing: 8
          visible: !root.expanded && root.hasActivities
          Rectangle {
            width: 6; height: 6; radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: root.screenRecording ? "#ff7272" : root.surfaceForeground
          }
          Text {
            text: root.activityLabel
            color: root.surfaceForeground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }

        // Resting notch carries ongoing activity; hover reveals its controls.
        // -------------------------------------------------- compact content
        Item {
          anchors.fill: parent
          anchors.leftMargin: Style.space(16)
          anchors.rightMargin: Style.space(16)
          anchors.topMargin: Style.space(14)
          anchors.bottomMargin: Style.space(12)
          opacity: root.notificationView ? 1 : 0
          visible: opacity > 0
          Behavior on opacity { NumberAnimation { duration: 160 } }

          MediaPane {
            foreground: root.surfaceForeground
            anchors.fill: parent
            visible: !root.showToastCard && root.hasMedia
            artSize: 88
            title: root.trackTitle
            artist: root.trackArtist
            artUrl: root.trackArt
            length: root.trackLength
            shownPosition: root.shownPosition
            progress: root.progress
            playing: root.playing
            canPrev: root.player ? root.player.canGoPrevious : false
            canToggle: root.player ? (root.player.canTogglePlaying || root.player.canPlay || root.player.canPause) : false
            canNext: root.player ? root.player.canGoNext : false
            onTogglePlay: root.togglePlay()
            onPrevious: root.previousTrack()
            onNext: root.nextTrack()
          }

          ToastPane {
            foreground: root.surfaceForeground
            anchors.fill: parent
            visible: root.showToastCard
            iconSize: 44
            app: root.toastField("app")
            summary: root.toastField("summary")
            body: root.toastField("body")
            image: root.toastField("image")
            onActivated: root.invokeToast()
          }

          Item {
            anchors.fill: parent
            visible: !root.showToastCard && !root.hasMedia

            Row {
              anchors.centerIn: parent
              spacing: Style.space(8)

              Text {
                text: "󰝚"
                color: Commons.Util.alpha(root.surfaceForeground, 0.40)
                font.family: Style.font.family
                font.pixelSize: Style.font.icon
              }

              Text {
                text: "Nothing playing"
                color: Commons.Util.alpha(root.surfaceForeground, 0.55)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
            }
          }
        }

        // --------------------------------------------------- pinned content
        Item {
          anchors.fill: parent
          opacity: root.expanded && !root.notificationView ? 1 : 0
          visible: opacity > 0
          Behavior on opacity { NumberAnimation { duration: 180 } }

          Row {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.top: parent.top
            anchors.topMargin: 12
            spacing: 6
            Repeater {
              model: ["󰝚  Now playing", "󰃭  Calendar", "󰐥  Activities" + (root.activeActivityCount ? " · " + root.activeActivityCount : "")]
              delegate: Rectangle {
                required property int index
                required property string modelData
                width: tabLabel.implicitWidth + 22
                height: 28
                radius: 14
                color: (index === 2 ? root.activitySelected : !root.activitySelected && root.calendarSelected === (index === 1))
                  ? Commons.Util.alpha(root.surfaceForeground, 0.12)
                  : (tabMouse.containsMouse ? Commons.Util.alpha(root.surfaceForeground, 0.06) : "transparent")
                Text {
                  id: tabLabel
                  anchors.centerIn: parent
                  text: modelData
                  color: root.surfaceForeground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                }
                MouseArea {
                  id: tabMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { root.activitySelected = index === 2; if (index < 2) root.calendarSelected = index === 1 }
                }
              }
            }
          }

          Item {
            anchors.fill: parent
            visible: !root.activitySelected
          Item {
            id: pinnedLeft
            anchors.left: parent.left
            anchors.leftMargin: Style.space(18)
            anchors.top: parent.top
            anchors.topMargin: 54
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(16)
            anchors.right: divider.left
            anchors.rightMargin: Style.space(14)

            MediaPane {
              id: mainMediaPane
              spectrum: root.audioLevels
              videoSource: root.videoSource
              captureEnabled: root.expanded && !root.notificationView && !root.activitySelected
              foreground: root.surfaceForeground
              anchors.fill: parent
              visible: !root.showToastCard && root.hasMedia
              artSize: 88
              title: root.trackTitle
              artist: root.trackArtist
              artUrl: root.trackArt
              length: root.trackLength
              shownPosition: root.shownPosition
              progress: root.progress
              playing: root.playing
              canPrev: root.player ? root.player.canGoPrevious : false
              canToggle: root.player ? (root.player.canTogglePlaying || root.player.canPlay || root.player.canPause) : false
              canNext: root.player ? root.player.canGoNext : false
              onTogglePlay: root.togglePlay()
              onPrevious: root.previousTrack()
              onNext: root.nextTrack()
            }

            ToastPane {
            foreground: root.surfaceForeground
              anchors.fill: parent
              visible: root.showToastCard
              iconSize: 44
              app: root.toastField("app")
              summary: root.toastField("summary")
              body: root.toastField("body")
              image: root.toastField("image")
              onActivated: root.invokeToast()
            }

            Item {
              anchors.fill: parent
              visible: !root.showToastCard && !root.hasMedia

              Row {
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  text: "󰝚"
                  color: Commons.Util.alpha(root.surfaceForeground, 0.40)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.iconLarge
                }

                Text {
                  text: "Nothing playing"
                  color: Commons.Util.alpha(root.surfaceForeground, 0.55)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                }
              }
            }
          }

          Rectangle {
            id: divider
            width: 1
            anchors.top: parent.top
            anchors.topMargin: 54
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(18)
            anchors.right: rightPane.left
            anchors.rightMargin: Style.space(16)
            color: Commons.Util.alpha(root.surfaceForeground, 0.10)
          }

          Item {
            id: rightPane
            width: root.calendarSelected ? 214 : 150
            anchors.right: parent.right
            anchors.rightMargin: Style.space(18)
            anchors.top: parent.top
            anchors.topMargin: 54
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(16)

            CalendarPane {
            foreground: root.surfaceForeground
              id: calendarPane
              anchors.fill: parent
              visible: root.calendarSelected
            }

            Column {
              id: actionsColumn
              width: parent.width
              anchors.verticalCenter: parent.verticalCenter
              spacing: 10
              visible: !root.calendarSelected
              Repeater {
                model: [
                  { label: "󰎆  Open player", action: "player" },
                  { label: "󰕾  Sound", action: "sound" },
                  { label: "󰃭  Calendar", action: "calendar" }
                ]
                delegate: Rectangle {
                  required property var modelData
                  width: parent.width
                  height: 34
                  radius: 17
                  color: Commons.Util.alpha(root.surfaceForeground, actionMouse.containsMouse ? 0.14 : 0.07)
                  border.width: 1
                  border.color: Commons.Util.alpha(root.surfaceForeground, actionMouse.containsMouse ? 0.22 : 0.08)
                  opacity: modelData.action === "player" && (!root.player || !root.player.canRaise) ? 0.4 : 1
                  Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: root.surfaceForeground
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                  }
                  MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: modelData.action !== "player" || (root.player && root.player.canRaise)
                    onClicked: {
                      if (modelData.action === "calendar") root.calendarSelected = true
                      else if (modelData.action === "sound") {
                        root.closeAll()
                        Quickshell.execDetached(["omarchy-shell", "omarchy.audio", "toggle"])
                      } else if (root.player && root.player.canRaise) {
                        root.player.raise()
                        root.closeAll()
                      }
                    }
                  }
                }
              }
            }
          }
          }

          ActivityPane {
            id: activityPane
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 54
            height: implicitHeight
            visible: root.activitySelected
            foreground: root.surfaceForeground
            recording: root.screenRecording
            recordingTime: root.recordingTime
            stopPending: root.stopRecordingPending
            dictation: root.dictationState
            reminders: root.reminderCount
            stayAwake: root.stayAwake
            dnd: root.dnd
            idleAvailable: true
            notificationsAvailable: true
            onActionRequested: action => root.activityAction(action)
          }

        }

        // Hover catcher on top: never eats clicks, only tracks the pointer.
        MouseArea {
          anchors.fill: parent
          z: 1000
          acceptedButtons: Qt.NoButton
          hoverEnabled: true
          onEntered: { hoverExitTimer.stop(); if (!root.expanded && root.hasActivities && !root.playing) root.activitySelected = true; root.hovered = true }
          onExited: { hoverExitTimer.restart(); root.glassLightX = 0.25; root.glassLightY = 0.15 }
          onPositionChanged: mouse => {
            root.glassLightX = Math.max(0, Math.min(1, mouse.x / width))
            root.glassLightY = Math.max(0, Math.min(1, mouse.y / height))
          }
        }
      }
    }

    // The clock strip: clicking the date opens the notch, right-click still
    // cycles the clock format and middle-click still opens the timezone menu.
    MouseArea {
      id: clockArea
      property bool suppressHover: false
      x: root.clockX
      y: 0
      width: root.clockHitWidth
      height: root.topOffset
      enabled: !root.pinned && root.topOffset > 0
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        if (suppressHover) return
        hoverExitTimer.stop()
        if (!root.expanded && root.hasActivities && !root.playing) root.activitySelected = true
        root.hovered = true
      }
      onExited: { suppressHover = false; hoverExitTimer.restart() }
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) clockCycleProc.running = true
        else if (mouse.button === Qt.MiddleButton) Quickshell.execDetached(["omarchy-menu-timezone"])
        else { if (root.hasActivities && !root.playing) root.activitySelected = true; root.pin() }
      }
    }

    // Clicking the same clock spot closes the pinned card.
    MouseArea {
      x: root.clockX
      y: 0
      width: root.clockHitWidth
      height: root.topOffset
      enabled: root.pinned && root.topOffset > 0
      cursorShape: Qt.PointingHandCursor
      onClicked: { clockArea.suppressHover = true; root.closeAll() }
    }
  }

  IpcHandler {
    target: "mark.notch"

    function ping(): string { return "ok" }
    function activities(): string { root.activitySelected = true; root.pin(); return "ok" }
    function show(): string { root.pin(); return "ok" }
    function hide(): string { root.closeAll(); return "ok" }
    function calendar(): string { root.activitySelected = false; root.calendarSelected = true; root.pin(); return "ok" }
    function music(): string { root.activitySelected = false; root.calendarSelected = false; root.pin(); return "ok" }
    function toggle(): string {
      if (root.pinned) root.closeAll()
      else root.pin()
      return "ok"
    }
    function debug(): string {
      return JSON.stringify({
        cardWidth: root.cardWidth,
        cardHeight: root.cardHeight,
        cardY: root.cardY,
        calendarSelected: root.calendarSelected,
        activitySelected: root.activitySelected,
        recording: root.screenRecording,
        recordingTime: root.recordingTime,
        dictationState: root.dictationState,
        reminderCount: root.reminderCount,
        stayAwake: root.stayAwake,
        dnd: root.dnd,
        activeActivityCount: root.activeActivityCount,
        surfaceColor: root.surfaceColor.toString(),
        surfaceAlpha: root.surfaceColor.a,
        liquidGlassReady: liquidGlass.ready,
        liquidGlassLog: liquidGlass.shaderLog,
        notificationView: root.notificationView,
        videoSource: root.videoSource ? root.videoSource.title : null,
        videoApp: root.videoSource ? root.videoSource.appId : null,
        videoReady: mainMediaPane.videoReady,
        visualizerActive: root.visualizerActive,
        visualizerRunning: audioAnalyzer.running,
        audioFrames: root.audioFrames,
        audioPeak: root.audioLevels.length ? Math.max.apply(null, root.audioLevels) : 0,
        videoSize: mainMediaPane.videoSize,
        measuredToastHeight: toastMeasure.implicitHeight,
        transparentBar: root.transparentBar,
        barThemeColor: Commons.Color.bar.background.toString(),
        hovered: root.hovered,
        pinned: root.pinned,
        expanded: root.expanded,
        toastActive: root.toastActive,
        hasMedia: root.hasMedia,
        barSize: root.barSize,
        fullscreenOnScreen: root.fullscreenOnScreen,
        barVisible: root.barVisible,
        topOffset: root.topOffset,
        notifications: root.liveNotifications.length,
        clockHover: clockArea.containsMouse,
        clockHitWidth: root.clockHitWidth,
        clockHitX: root.clockX,
        clickAwayY: maskRegion.y,
        calendar: calendarPane.debugState()
      })
    }
  }
}
