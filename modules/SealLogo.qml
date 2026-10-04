import QtQuick
import qs.Commons

// The Nerdibeard seal ("Siegel nb, leichter", logo design round 04.10.): a
// block of the bar's ink with the initials nb cut out in squared seal script,
// the 16 px drawing with a 1 px rim on whole pixels. Where a cut stroke turns
// its outer corner keeps one pixel of ink, and the block lacks its corner
// pixels – a worn stone, not a UI square. The cut shows the ground: nothing is
// drawn there in the bar.
// Motion, the reviewed version (expressive only at the one-time arrival):
//   arrival: one impression, 0.32 s – the ink at the letters' edges prints at
//     once, the rest soaks out to the rim in a fixed order; then it is still.
//   hover: nothing. press: the ink takes the tab's tone (`pressInk`) inside
//     the fixed outline. tab (`tab`, Workspaces.qml runs the ink out into the
//     tab): the block in `tabInk` with the nb cut in `cutInk`.
//   reduced motion: a 0.12 s cross-fade instead of the impression; press and
//     tab change colour in 0.12 s cross-fades too (no impulse, no front).
// `rows` and `ranks` come from the design's own code (logo-bewegung
// 06-empfehlung.js): '#' ink · 'x' cut · '.' outside; rank 0 = the letters'
// edges (time 0), 1…89 = the order of the rest (chamfer distance to the cut
// plus value noise, seed 18) at times 0.12…1 of the impression.
Item {
  id: seal

  property color ink: "black"
  property color pressInk: ink
  property bool pressed: false
  property bool tab: false
  property color tabInk: ink
  property color cutInk: "transparent"

  readonly property var rows: [
    ".##############.",
    "#########xx#####",
    "#########xx#####",
    "#########xx#####",
    "#########xx#####",
    "#########xx#####",
    "#########xx#####",
    "##xxxx###xxxxx##",
    "#xxxxxx##xxxxxx#",
    "#xx##xx##xx##xx#",
    "#xx##xx##xx##xx#",
    "#xx##xx##xx##xx#",
    "#xx##xx##xx##xx#",
    "#xx##xx##xxxxxx#",
    "#xx##xx###xxxx##",
    ".##############."
  ]
  readonly property var ranks: [
    -1, 89, 88, 86, 81, 71, 55, 27,  2,  0,  0,  4, 31, 51, 67, -1,
    87, 85, 84, 83, 79, 66, 47, 18,  0, -1, -1,  0, 29, 50, 62, 74,
    82, 80, 77, 75, 76, 64, 44, 14,  0, -1, -1,  0, 36, 56, 68, 73,
    78, 70, 60, 59, 61, 63, 43, 12,  0, -1, -1,  0, 39, 57, 69, 72,
    65, 54, 37, 35, 45, 52, 49, 17,  0, -1, -1,  0, 28, 48, 53, 58,
    46, 32,  7,  6, 25, 34, 40, 20,  0, -1, -1,  0, 13, 19, 30, 42,
    41,  8,  0,  0,  0,  0, 10, 16,  0, -1, -1,  0,  0,  0,  5, 33,
    26,  0, -1, -1, -1, -1,  0,  1,  0, -1, -1, -1, -1, -1,  0,  3,
     0, -1, -1, -1, -1, -1, -1,  0,  0, -1, -1, -1, -1, -1, -1,  0,
     0, -1, -1,  0,  0, -1, -1,  0,  0, -1, -1,  0,  0, -1, -1,  0,
     0, -1, -1,  0,  0, -1, -1,  0,  0, -1, -1,  0,  0, -1, -1,  0,
     0, -1, -1,  0,  0, -1, -1,  0,  0, -1, -1,  0,  0, -1, -1,  0,
     0, -1, -1,  0,  0, -1, -1,  0,  0, -1, -1,  0,  0, -1, -1,  0,
     0, -1, -1,  0,  0, -1, -1,  0,  0, -1, -1, -1, -1, -1, -1,  0,
     0, -1, -1,  0,  0, -1, -1,  0, 24,  0, -1, -1, -1, -1,  0, 21,
    -1,  0,  0,  9, 23,  0,  0, 22, 38, 15,  0,  0,  0,  0, 11, -1
  ]
  readonly property int restCount: 89
  function due(rank) { return rank <= 0 ? 0 : 0.12 + 0.88 * (rank - 1) / (restCount - 1) }

  implicitWidth: 16
  implicitHeight: 16

  // arrival: p runs 0 → 1 in 0.32 s; a pixel shows once its time is ≤ k
  property real p: 0
  readonly property real k: 1 - Math.pow(1 - p, 1.6)
  opacity: Style.reduceMotion ? 0 : 1
  NumberAnimation { id: impress; target: seal; property: "p"; from: 0; to: 1; duration: 320 }
  NumberAnimation { id: fadeIn; target: seal; property: "opacity"; from: 0; to: 1; duration: 120; easing.type: Easing.InOutQuad }
  Component.onCompleted: {
    if (Style.reduceMotion) { p = 1; opacity = 0; fadeIn.start() }
    else impress.start()
  }

  Repeater {
    model: 256
    Rectangle {
      required property int index
      readonly property string ch: seal.rows[Math.floor(index / 16)].charAt(index % 16)
      x: index % 16
      y: Math.floor(index / 16)
      width: 1; height: 1
      antialiasing: false
      // the cut is drawn only on the tab (in the bar the ground shows through)
      visible: ch === "#" ? seal.due(seal.ranks[index]) <= seal.k : ch === "x"
      color: ch === "x" ? (seal.tab ? seal.cutInk : Qt.rgba(seal.cutInk.r, seal.cutInk.g, seal.cutInk.b, 0))
             : seal.tab ? seal.tabInk : seal.pressed ? seal.pressInk : seal.ink
      Behavior on color { enabled: Style.reduceMotion; ColorAnimation { duration: 120 } }
    }
  }
}
