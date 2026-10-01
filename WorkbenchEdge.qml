import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

PanelWindow {
  id: win
  property int barHeight: Style.bar.sizeHorizontal
  readonly property real scale: devicePixelRatio > 0 ? devicePixelRatio : 1
  readonly property var geometry: edgeGeometry(barHeight, scale)

  // Layer surfaces use integer logical bounds; snap the paint inside that
  // envelope so each line occupies exactly one device pixel at any scale.
  function edgeGeometry(barHeight, scale) {
    var bottom = Math.round(barHeight * scale)
    var top = Math.floor((bottom - 2) / scale)
    var origin = Math.round(top * scale)
    return { top: top, height: Math.ceil((bottom - origin) / scale),
             highlightY: (bottom - origin - 2) / scale }
  }

  // On Overlay so it sits above the bar; a fullscreen window must not get
  // a line across its top, so it hides while one covers this monitor.
  readonly property var hyprMonitor: Hyprland.monitorFor(screen)
  readonly property bool fullscreen: !!(hyprMonitor && hyprMonitor.activeWorkspace && hyprMonitor.activeWorkspace.hasFullscreen)
  visible: !remapGuard.remapping && !fullscreen
  color: "transparent"
  surfaceFormat.opaque: false
  anchors { top: true; left: true; right: true }
  margins.top: geometry.top
  implicitHeight: geometry.height
  exclusiveZone: 0
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "amiga-bar-edge"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  ScreenMoveRemap { id: remapGuard; window: win }

  Rectangle {
    y: win.geometry.highlightY
    width: parent.width; height: 1 / win.scale
    color: Util.alpha(Color.bar.text, 0.15)
  }
  Rectangle {
    y: win.geometry.highlightY + 1 / win.scale
    width: parent.width; height: 1 / win.scale
    color: Qt.darker(Color.bar.background, 1.6)
  }
}
