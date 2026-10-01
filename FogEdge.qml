import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Fog look (test): the bar's lower edge as soft, slightly lumpy fog.
// A band in the bar's colour reaches up into the bar (outside this window)
// and small lumps hang from it; FogLayer blurs and cuts them softly, so the
// bar seems to end in fog instead of a hard line. Popups that grow out of
// the bar in the fog look (Amiga Island notes) merge with it.
PanelWindow {
  id: win
  property int barHeight: Style.bar.sizeHorizontal
  // The colour the bar ends in (opaque).
  property color fogColor: Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, 1)
  readonly property real depth: Math.max(10, Math.round(barHeight * 0.55))
  readonly property real margin: 32

  // Hidden under fullscreen windows, as the Workbench edge.
  readonly property var hyprMonitor: Hyprland.monitorFor(screen)
  readonly property bool fullscreen: !hyprMonitor || !hyprMonitor.activeWorkspace || hyprMonitor.activeWorkspace.hasFullscreen
  visible: !remapGuard.remapping && !fullscreen
  color: "transparent"
  surfaceFormat.opaque: false
  anchors { top: true; left: true; right: true }
  margins.top: barHeight
  implicitHeight: depth
  // Ignore alone (exclusiveZone would force Normal and push it down).
  exclusionMode: ExclusionMode.Ignore
  // Top, like the bar: windows stay under it, popups (Overlay) over it.
  WlrLayershell.namespace: "amiga-bar-fog"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  ScreenMoveRemap { id: remapGuard; window: win }

  FogLayer {
    x: -win.margin
    y: -win.margin
    width: win.width + win.margin * 2
    height: win.depth + win.margin
    color: win.fogColor
    blurMax: 24
    threshold: 0.4
    softness: 0.5

    // the bar itself, above this window
    Rectangle { width: parent.width; height: win.margin; color: "white" }
    // lumps along the edge: fixed pseudo-random sizes, so the edge is
    // irregular but still (no motion, nothing to repaint)
    Repeater {
      model: Math.ceil((win.width + win.margin * 2) / 12) + 1
      Rectangle {
        required property int index
        readonly property real r: 3 + (index * 37) % 5
        x: index * 12 + (index * 13) % 9 - r
        y: win.margin - r * 1.3 + (index * 7) % 3
        width: r * 2; height: r * 2; radius: r
        color: "white"
      }
    }
  }
}
