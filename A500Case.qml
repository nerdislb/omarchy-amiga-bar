import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Bar form "A500 case edge": the bar as the top edge of an Amiga 500, inside
// the normal bar height — a flat top face, the darker wedge front with a
// light crease, fine cooling grooves, an LED window around the compact
// status strip and the drive slot under the island (DF0 lights while a
// note comes out of it). Drawn on the Bottom layer under the native bar,
// whose own fill the engine makes transparent (bin/bar-form.py); the bar's
// widgets stay exactly where they are. No input.
PanelWindow {
  id: win

  property int barHeight: Style.bar.sizeHorizontal
  property var slot: null        // { x, w } of the island in this bar, or null
  property var led: null         // { x, w } of the compact strip, or null
  property bool noteOpen: false  // a note is coming out of the slot

  // The theme's bar colour, opaque (the bar's own fill is transparent now).
  readonly property color base: Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, 1)
  readonly property color ink: Color.bar.text
  readonly property bool dark: (0.299 * base.r + 0.587 * base.g + 0.114 * base.b) < 0.5
  function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }

  // Same tones as the concept study (02-gehaeuse): beige-ish in light themes.
  readonly property color topFace: dark ? mix(base, ink, 0.07) : base
  readonly property color front: dark ? Qt.darker(base, 1.35) : mix(base, ink, 0.5)
  readonly property color crease: dark ? mix(base, ink, 0.32) : "#ffffff"
  readonly property color shadow: dark ? Qt.darker(base, 1.8) : mix(base, ink, 0.45)
  readonly property color groove: dark ? Qt.darker(base, 1.8) : mix(base, ink, 0.35)
  readonly property color grooveHi: dark ? mix(base, ink, 0.16) : "#ffffff"
  readonly property color windowFill: dark ? Qt.darker(base, 1.8) : mix(base, ink, 0.82)

  readonly property int topH: Math.round(barHeight * 0.73)
  readonly property int frontH: barHeight - topH
  readonly property real slotCx: slot ? slot.x + slot.w / 2 : width / 2
  readonly property int slotW: Math.round(Math.max(120, Math.min(220, slot ? slot.w * 0.8 : 200)))

  color: "transparent"
  surfaceFormat.opaque: false
  anchors { top: true; left: true; right: true }
  implicitHeight: barHeight
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "amiga-bar-case"
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  // top face and wedge front
  Rectangle { width: parent.width; height: win.topH; color: win.topFace }
  Rectangle { y: win.topH; width: parent.width; height: win.frontH; color: win.front }
  Rectangle { y: win.topH; width: parent.width; height: 1; color: win.crease; opacity: 0.7 }
  Rectangle { y: win.barHeight - 1; width: parent.width; height: 1; color: win.shadow }

  // cooling grooves in the quiet stretch left of the island
  Repeater {
    model: 18
    Item {
      required property int index
      x: win.slotCx - win.slotW / 2 - 90 - (18 - index) * 12
      y: Math.round(win.topH * 0.3)
      Rectangle { width: 6; height: 2; color: win.groove; opacity: 0.9 }
      Rectangle { y: 2; width: 6; height: 1; color: win.grooveHi; opacity: 0.5 }
      Rectangle { y: Math.round(win.topH * 0.32); width: 6; height: 2; color: win.groove; opacity: 0.9 }
      Rectangle { y: Math.round(win.topH * 0.32) + 2; width: 6; height: 1; color: win.grooveHi; opacity: 0.5 }
    }
  }

  // LED window: a recessed panel around the compact strip
  Item {
    visible: !!win.led
    x: win.led ? win.led.x - 6 : 0
    y: 3
    width: win.led ? win.led.w + 12 : 0
    height: win.topH - 5
    Rectangle { anchors.fill: parent; color: win.windowFill; opacity: win.dark ? 1 : 0.25 }
    // inset bevel: dark top/left, light bottom/right
    Rectangle { width: parent.width; height: 1; color: win.shadow }
    Rectangle { width: 1; height: parent.height; color: win.shadow }
    Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: win.crease; opacity: 0.6 }
    Rectangle { x: parent.width - 1; width: 1; height: parent.height; color: win.crease; opacity: 0.6 }
  }

  // drive slot in the wedge front, with its eject button
  Item {
    x: Math.round(win.slotCx - win.slotW / 2)
    y: win.topH
    width: win.slotW
    height: win.frontH
    Rectangle { x: -1; y: 1; width: parent.width + 2; height: Math.min(6, parent.height - 1); color: win.shadow }
    Rectangle { y: 2; width: parent.width; height: Math.max(2, Math.min(4, parent.height - 3)); color: "#000000"; opacity: 0.85 }
    Rectangle { y: Math.min(6, parent.height - 1); width: parent.width; height: 1; color: win.crease; opacity: 0.7 }
    // the slot's lip darkens while a note is coming out
    Rectangle { y: 2; width: parent.width; height: 2; color: win.shadow; visible: win.noteOpen }
    Rectangle { x: parent.width + 8; y: 2; width: 10; height: Math.min(4, parent.height - 3); color: win.groove }
    Rectangle { x: parent.width + 8; y: 2; width: 10; height: 1; color: win.grooveHi; opacity: 0.6 }
  }
}
