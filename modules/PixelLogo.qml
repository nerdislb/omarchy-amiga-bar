import QtQuick
import Quickshell.Io
import qs.Commons

// Pixel logos in the NerdWorkbench brick grid (1.5 × 2 px per brick, column
// edges on whole pixels, 16 px tall), so they sit with the pixel font as one
// system. A font glyph has one colour; these logos need several, hence QML.
//   amiga — the rainbow double tick (front tick in theme colours, the tick
//           behind it darker, as the outline does in the original)
//   boing — the Boing ball (theme red and white)
// Trademarks: the Amiga tick and Boing ball belong to their owners; private
// build, see FONTS.md before any release.
Item {
  id: logo

  property string kind: "amiga"

  // B blue · G green · Y yellow · O orange · R red · W white; lowercase = rear tick
  readonly property var arts: ({
    amiga: [
      ".........RRrr",
      "........RRrr.",
      ".......OOoo..",
      "......OOoo...",
      ".....YYyy....",
      "BBbbYYyy.....",
      ".BBGGgg......",
      "..GGgg......."
    ],
    boing: [
      "...WWRR...",
      ".RRWWRRWW.",
      "WWRRRWWWRR",
      "WWRRRWWWRR",
      "RRWWWRRWWW",
      "RRWWWRRWWW",
      ".WWRRWWRR.",
      "...RRWW..."
    ]
  })
  readonly property var rows: arts[kind] || arts.amiga
  readonly property int columns: rows.length ? rows[0].length : 0
  function colX(c) { return Math.floor(1.5 * c) }

  implicitWidth: colX(columns)
  implicitHeight: rows.length * 2

  // Theme palette (colors.toml), with the classic logo colours as fallback.
  property var pal: ({})
  FileView {
    path: Color.currentThemePath + "/colors.toml"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      var out = {}, re = /^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6,8})"/gm, m
      var t = text()
      while ((m = re.exec(t)) !== null) out[m[1]] = m[2]
      logo.pal = out
    }
  }
  readonly property color red: pal.color1 || pal.red || "#e0302a"
  readonly property color green: pal.color2 || pal.green || "#2a9d4a"
  readonly property color yellow: pal.color3 || pal.yellow || "#e0c21c"
  readonly property color blue: pal.color4 || pal.blue || "#2c6fd6"
  readonly property color orange: pal.orange || Qt.rgba((red.r + yellow.r) / 2, (red.g + yellow.g) / 2, (red.b + yellow.b) / 2, 1)
  function tone(ch) {
    var up = ch.toUpperCase()
    var c = up === "R" ? red : up === "O" ? orange : up === "Y" ? yellow : up === "G" ? green : up === "B" ? blue : "#f2efe6"
    return ch === up ? c : Qt.darker(c, 1.65)
  }

  Repeater {
    model: logo.rows.length * logo.columns
    Rectangle {
      required property int index
      readonly property int r: Math.floor(index / logo.columns)
      readonly property int c: index % logo.columns
      readonly property string ch: logo.rows[r].charAt(c)
      visible: ch !== "."
      x: logo.colX(c)
      y: r * 2
      width: logo.colX(c + 1) - x
      height: 2
      color: visible ? logo.tone(ch) : "transparent"
      antialiasing: false
    }
  }
}
