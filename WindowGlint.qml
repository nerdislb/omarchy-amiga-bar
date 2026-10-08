import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import "bridge" as Bridge

// A chrome glint that runs once round the focused window's frame (bar option
// `frames glint`, metal themes; 08.10.2026). Hyprland can only turn a linear
// gradient on its border (borderangle): in 1° steps, racing along the edges and
// lingering at the corners. So the glint is drawn here instead – MetalShape
// kind "frame" over Hyprland's own border, placed by arc length, so it keeps an
// even pace round the corners, slowing towards the end and fading out.
//
// Only while it runs is there a surface: a click-through Overlay layer the
// size of the frame. It starts once the window has settled (open and
// workspace animations) and stops when the window moves, resizes, goes
// fullscreen or closes, or the workspace changes – it never trails a moving
// window. trigger() glints the focused window on demand (IPC `glintWindow`),
// for other events to reuse.
Scope {
  id: root

  property bool enabled: false
  readonly property var metal: Bridge.ModuleBus.metal
  // one turn; the glint's lead in px (its tail is 2.5× as long)
  readonly property int durationMs: metal && Number(metal.frameGlintMs) > 0 ? Number(metal.frameGlintMs) : 2800
  readonly property real leadPx: 90

  // the frame being glinted, in the target screen's coordinates
  property string screenName: ""
  property real fx: 0
  property real fy: 0
  property real fw: 0
  property real fh: 0
  property bool running: false
  property real sweep: 0
  property real amount: 0

  property int borderSize: 2
  property real rounding: 0
  property bool justOpened: false

  function stop() {
    anim.stop()
    running = false
    amount = 0
  }
  function trigger() {
    if (!metal || Style.reduceMotion) return false
    stop()
    settle.interval = 40
    settle.restart()
    return true
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var n = event ? event.name : ""
      if (n === "configreloaded") { if (!options.running) options.running = true; return }
      if (n === "openwindow") root.justOpened = true
      if (n === "activewindowv2") {
        root.stop()
        if (!root.enabled || !root.metal || Style.reduceMotion) return
        // a new window animates in (windowsIn ~0.4 s), a workspace slides (~0.2 s)
        settle.interval = root.justOpened ? 480 : 300
        root.justOpened = false
        settle.restart()
      } else if (n === "workspacev2" || n === "movewindowv2" || n === "fullscreen" || n === "changefloatingmode" || n === "closewindow" || n === "resizewindow") {
        settle.stop()
        root.stop()
      }
    }
  }
  Timer { id: settle; interval: 300; onTriggered: query.running = true }

  // border size and corner rounding, read again on config reloads
  Process {
    id: options
    running: true
    command: ["sh", "-c", "hyprctl -j getoption general:border_size; echo; hyprctl -j getoption decoration:rounding"]
    stdout: StdioCollector {
      onStreamFinished: {
        var parts = String(text || "").split(/\n(?=\{)/)
        try { root.borderSize = Math.max(0, Number(JSON.parse(parts[0]).int)) } catch (e) {}
        try { root.rounding = Math.max(0, Number(JSON.parse(parts[1]).int)) } catch (e) {}
      }
    }
  }

  Process {
    id: query
    command: ["sh", "-c", "hyprctl -j activewindow; printf '\\n---\\n'; hyprctl -j monitors"]
    stdout: StdioCollector {
      onStreamFinished: {
        var parts = String(text || "").split("\n---\n")
        var w, mons
        try { w = JSON.parse(parts[0]); mons = JSON.parse(parts[1]) } catch (e) { return }
        if (!w || !w.address || !w.size || w.fullscreen > 0 || w.hidden) return
        var mon = null
        for (var i = 0; i < mons.length; i++) if (mons[i].id === w.monitor) mon = mons[i]
        if (!mon) return
        var b = root.borderSize
        root.screenName = mon.name
        root.fx = w.at[0] - mon.x - b
        root.fy = w.at[1] - mon.y - b
        root.fw = w.size[0] + 2 * b
        root.fh = w.size[1] + 2 * b
        if (root.fw < 40 || root.fh < 40) return
        root.running = true
        anim.restart()
      }
    }
  }

  // one turn from the top edge's left end, slowing towards the end; the glint
  // fades over the last part instead of stopping dead
  ParallelAnimation {
    id: anim
    NumberAnimation { target: root; property: "sweep"; from: 0; to: 1; duration: root.durationMs; easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "amount"; from: 1; to: 0; duration: root.durationMs; easing.type: Easing.InQuart }
    onFinished: root.running = false
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        readonly property real pad: 4
        visible: root.running && root.screenName === modelData.name
        color: "transparent"
        surfaceFormat.opaque: false
        anchors { top: true; left: true }
        margins.left: Math.round(root.fx - pad)
        margins.top: Math.round(root.fy - pad)
        implicitWidth: Math.round(root.fw + 2 * pad)
        implicitHeight: Math.round(root.fh + 2 * pad)
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "tusche-bar-window-glint"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        MetalShape {
          anchors.fill: parent
          spec: root.metal
          kind: "frame"
          pad: win.pad
          radius: root.rounding > 0 ? root.rounding + root.borderSize : 0
          tube: Math.max(1, root.borderSize)
          arc: root.leadPx / Math.max(1, 2 * (root.fw + root.fh))
          sweep: root.sweep
          sweepAmt: root.amount
        }
      }
    }
  }
}
