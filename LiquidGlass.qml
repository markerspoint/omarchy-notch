import QtQuick

// Wallpaper refraction and edge lighting above the compositor's frosted surface.
// The effect is separate from controls, so text and video are never distorted.
Item {
  id: glass
  property url wallpaperSource
  property real screenWidth: 1920
  property real screenHeight: 1080
  property real sceneX: 0
  property real sceneY: 0
  property real cornerRadius: 26
  property real lightX: 0.25
  property real lightY: 0.15
  readonly property bool ready: wallpaper.status === Image.Ready && lens.status !== ShaderEffect.Error
  readonly property string shaderLog: lens.log

  Image {
    id: wallpaper
    visible: false
    source: glass.wallpaperSource
    sourceSize: Qt.size(glass.screenWidth, glass.screenHeight)
    asynchronous: true
    cache: false
  }

  ShaderEffect {
    id: lens
    anchors.fill: parent
    visible: wallpaper.status === Image.Ready
    fragmentShader: Qt.resolvedUrl("liquid-glass.frag.qsb")
    property var wallpaperTex: wallpaper
    property vector2d resolution: Qt.vector2d(width, height)
    property vector2d screenSize: Qt.vector2d(glass.screenWidth, glass.screenHeight)
    property vector2d scenePosition: Qt.vector2d(glass.sceneX, glass.sceneY)
    property vector2d imageSize: Qt.vector2d(wallpaper.implicitWidth, wallpaper.implicitHeight)
    property vector2d lightPosition: Qt.vector2d(glass.lightX, glass.lightY)
    property real bottomRadius: glass.cornerRadius
  }
}
