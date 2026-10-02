import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "bridge" as Bridge

// Drop-down logo menu (Amiga Bar option `menu` = "drop"): one tall menu
// that folds out of the logo — with the fog look on it grows out of the
// bar as fog. On top the Omarchy menu itself (omarchy-menu.jsonc plus the
// user's extensions, read like the native menu), below our own groups.
// Submenus open inside it (‹ goes back); typing searches the whole tree.
// Keys: ↑↓ select · Enter/→ open · ←/Backspace back · Esc clears or closes.
// Lists the shell fills in (Apps, fonts) open the native menu there.
KeyboardPanel {
  id: menu

  // [{ kind: "omarchy" | "amiga", id, title }]; empty = the top level.
  property var stack: []
  property string query: ""
  property int current: -1
  property real slideX: 0
  property int slideDir: 1

  readonly property var level: stack.length ? stack[stack.length - 1] : null
  readonly property color ink: Color.popups.text
  readonly property string labelFamily: Bridge.ModuleBus.momentFamily
  readonly property int labelPx: Bridge.ModuleBus.momentPx(Style.font.body)
  readonly property int rowH: Math.max(Style.space(30), labelPx + Style.space(14))
  readonly property int rowRadius: Math.min(Style.cornerRadius, 6)

  padding: Style.space(8)
  focusTarget: keys
  contentWidth: Math.round(Math.max(Style.space(300), Math.min(Style.space(460), widest * labelPx * 0.62 + Style.space(120))))
  readonly property real headerH: Style.space(32) + 1 + Style.space(6)
  contentHeight: menu.fittedContentHeight(headerH + list.implicitHeight)
  Behavior on contentWidth { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
  Behavior on contentHeight { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }

  OmarchyMenuSource { id: source; live: menu.visible }
  FogPanel { panel: menu; fog: Bridge.ModuleBus.fog; color: Bridge.ModuleBus.fogColor }

  // ---------------------------------------------------------------- rows
  readonly property var groups: {
    var e = Bridge.ModuleBus.engine
    return e && menu.visible ? e.dropGroups() : []
  }
  function groupRows(g) {
    return (g ? g.items : []).map(function(it) {
      return it.separator ? { separator: true }
        : { kind: "amiga", label: it.label, note: it.note || "", checked: !!it.checked, disabled: !!it.disabled, run: it.action, path: g.title }
    })
  }
  readonly property var rows: {
    if (query) {
      var q = query.toLowerCase().trim()
      var own = []
      groups.forEach(function(g) {
        groupRows(g).forEach(function(r) { if (!r.separator && !r.disabled && r.label.toLowerCase().indexOf(q) !== -1) own.push(r) })
      })
      return source.search(query, 30).concat(own)
    }
    if (!level) {
      var top = groups.map(function(g) { return { kind: "group", id: g.id, label: g.title, title: g.title, icon: g.icon } })
      return source.children("root").concat(top.length ? [{ separator: true }] : [], top)
    }
    if (level.kind === "omarchy") return source.children(level.id)
    for (var i = 0; i < groups.length; i++) if (groups[i].id === level.id) return groupRows(groups[i])
    return []
  }
  readonly property int widest: rows.reduce(function(w, r) {
    return Math.max(w, String(r.label || "").length + (r.note ? String(r.note).length * 0.8 + 2 : 0) + (query && r.path ? String(r.path).length * 0.8 + 2 : 0))
  }, 18)

  function selectable(i) { var r = rows[i]; return !!r && !r.separator && !r.disabled }
  function move(step) {
    var n = rows.length, i = current < 0 ? (step > 0 ? -1 : 0) : current
    for (var k = 0; k < n; k++) { i = (i + step + n) % n; if (selectable(i)) { current = i; return } }
  }
  function firstSelectable() { for (var i = 0; i < rows.length; i++) if (selectable(i)) return i; return -1 }

  function slide(dir) {
    slideDir = dir
    slideIn.restart()
  }
  function push(next) {
    stack = stack.concat([next]); query = ""
    current = keys.keyboard ? firstSelectable() : -1
    slide(1)
  }
  function back() {
    if (query) { query = ""; return }
    if (!stack.length) return
    stack = stack.slice(0, -1)
    current = keys.keyboard ? firstSelectable() : -1
    slide(-1)
  }
  function finish(fn) {
    menu.close()
    Qt.callLater(fn)
  }
  function activate(r) {
    if (!r || r.separator || r.disabled) return
    if (r.kind === "menu") push({ kind: "omarchy", id: r.target, title: r.title })
    else if (r.kind === "group") push({ kind: "amiga", id: r.id, title: r.title })
    else if (r.kind === "provider") finish(function() { Util.execDetached("omarchy-menu summon " + Util.shellQuote(r.id)) })
    else if (r.kind === "action") finish(function() { Util.execDetached(r.action) })
    else if (r.kind === "amiga" && typeof r.run === "function") finish(r.run)
  }

  onQueryChanged: current = query ? firstSelectable() : (keys.keyboard ? firstSelectable() : -1)
  // ---------------------------------------------------------------- view
  component Label: Text {
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: menu.labelFamily
    font.pixelSize: menu.labelPx
    color: menu.ink
  }

  Item {
    id: keys
    anchors.fill: parent
    focus: true
    // Keyboard selection wins over hover until the pointer really moves
    // (delegates appearing under a still cursor send hover events too).
    property bool keyboard: false
    property bool pointerKnown: false
    property real pointerX: 0
    property real pointerY: 0
    function pointerMoved(area, mouse) {
      var p = area.mapToItem(keys, mouse.x, mouse.y)
      var moved = pointerKnown && (Math.abs(p.x - pointerX) > 0.5 || Math.abs(p.y - pointerY) > 0.5)
      pointerKnown = true; pointerX = p.x; pointerY = p.y
      if (moved) keyboard = false
      return moved
    }

    // (Inside an Item: the panel's default content only takes Items.)
    Connections {
      target: menu
      function onOpenChanged() {
        if (!menu.open) return
        menu.stack = []; menu.query = ""; menu.current = -1
        keys.keyboard = false; keys.pointerKnown = false
        menu.slideX = 0
        source.evaluate()
      }
    }

    NumberAnimation {
      id: slideIn
      target: menu; property: "slideX"
      from: menu.slideDir * Style.space(28); to: 0
      duration: Style.duration(200); easing.type: Easing.OutCubic
    }

    Keys.onPressed: function(e) {
      var plain = !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
      if (e.key === Qt.Key_Escape) { if (menu.query) menu.query = ""; else menu.close() }
      else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab) { keys.keyboard = true; menu.move(1) }
      else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) { keys.keyboard = true; menu.move(-1) }
      else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || (e.key === Qt.Key_Right && !menu.query)) {
        keys.keyboard = true
        menu.activate(menu.rows[menu.current >= 0 ? menu.current : menu.firstSelectable()])
      }
      else if (e.key === Qt.Key_Left && !menu.query) { keys.keyboard = true; menu.back() }
      else if (e.key === Qt.Key_Backspace) { if (menu.query) menu.query = menu.query.slice(0, -1); else { keys.keyboard = true; menu.back() } }
      else if (plain && e.text && e.text.length === 1 && e.text > " ") menu.query += e.text
      else if (plain && e.key === Qt.Key_Space && menu.query) menu.query += " "
      else return
      e.accepted = true
    }

    Column {
      id: body
      width: parent.width

      // header: OMARCHY · ‹ Submenu · search
      Item {
        id: header
        width: parent.width
        height: Style.space(32)
        Label {
          id: backGlyph
          visible: menu.stack.length > 0 || menu.query !== ""
          x: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: "‹"
          font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.body + 4)
          color: Util.alpha(menu.ink, 0.7)
          MouseArea { anchors.fill: parent; anchors.margins: -Style.space(6); cursorShape: Qt.PointingHandCursor; onClicked: menu.back() }
        }
        Label {
          id: title
          x: backGlyph.visible ? backGlyph.x + backGlyph.implicitWidth + Style.space(10) : Style.space(10)
          width: closeGlyph.x - x - Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          elide: Text.ElideRight
          text: menu.query ? "⌕  " + menu.query + "▏" : (menu.level ? menu.level.title : "Omarchy").toUpperCase()
          font.letterSpacing: menu.query ? 0 : Style.space(2.5)
          font.pixelSize: menu.query ? menu.labelPx : Bridge.ModuleBus.momentPx(Math.max(10, Style.font.body - 2))
          color: Util.alpha(menu.ink, menu.query ? 1 : 0.72)
        }
        Label {
          id: closeGlyph
          x: parent.width - implicitWidth - Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: "×"
          font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.body + 2)
          color: Util.alpha(menu.ink, 0.6)
          MouseArea { anchors.fill: parent; anchors.margins: -Style.space(6); cursorShape: Qt.PointingHandCursor; onClicked: menu.close() }
        }
      }
      Rectangle { x: Style.space(6); width: parent.width - 2 * x; height: 1; color: Util.alpha(menu.ink, 0.12) }
      Item { width: 1; height: Style.space(6) }

      Flickable {
        id: flick
        width: parent.width
        height: Math.max(0, keys.height - menu.headerH)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        opacity: 1 - Math.abs(menu.slideX) / Style.space(40)

        Column {
          id: list
          x: menu.slideX
          width: flick.width

          Repeater {
            id: rowRepeater
            model: menu.rows.length
            Item {
              id: row
              required property int index
              readonly property var r: menu.rows[index] || ({})
              readonly property bool hot: menu.current === index && !r.separator && !r.disabled
              readonly property bool opens: r.kind === "menu" || r.kind === "group" || r.kind === "provider"
              width: list.width
              height: r.separator ? Style.space(13) : menu.rowH
              onHotChanged: if (hot) {
                if (row.y < flick.contentY) flick.contentY = row.y
                else if (row.y + row.height > flick.contentY + flick.height) flick.contentY = row.y + row.height - flick.height
              }

              Rectangle {
                visible: row.r.separator === true
                x: Style.space(8); width: parent.width - 2 * x; height: 1
                anchors.verticalCenter: parent.verticalCenter
                color: Util.alpha(menu.ink, 0.12)
              }
              Rectangle {
                anchors.fill: parent
                visible: row.hot
                radius: menu.rowRadius
                color: Util.alpha(menu.ink, 0.09)
              }

              Text {
                id: icon
                visible: !row.r.separator
                x: Style.space(10); width: Style.space(22)
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText; renderType: Text.NativeRendering
                text: row.r.icon || ""
                font.family: row.r.iconFont || Style.font.menuFamily
                font.pixelSize: Style.font.body + 2
                color: Util.alpha(menu.ink, row.hot ? 0.95 : 0.62)
                opacity: row.r.disabled ? 0.45 : 1
              }
              Label {
                id: label
                visible: !row.r.separator
                x: icon.x + icon.width + Style.space(10)
                width: Math.max(0, trail.x - x - Style.space(8))
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: row.r.label || ""
                opacity: row.r.disabled ? 0.45 : 1
              }
              Row {
                id: trail
                visible: !row.r.separator
                x: parent.width - width - Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(8)
                Label {
                  visible: text !== ""
                  anchors.verticalCenter: parent.verticalCenter
                  text: row.r.note || (menu.query ? (row.r.path || "") : "")
                  font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.caption)
                  color: Util.alpha(menu.ink, 0.5)
                }
                Label {
                  visible: row.r.checked === true
                  anchors.verticalCenter: parent.verticalCenter
                  text: "✓"
                  color: Util.alpha(menu.ink, 0.8)
                }
                Label {
                  visible: row.opens
                  anchors.verticalCenter: parent.verticalCenter
                  text: "›"
                  font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.body + 2)
                  color: Util.alpha(menu.ink, row.hot ? 0.8 : 0.4)
                }
              }

              MouseArea {
                anchors.fill: parent
                enabled: !row.r.separator && !row.r.disabled
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: function(mouse) { if (keys.pointerMoved(this, mouse)) menu.current = row.index }
                onEntered: if (!keys.keyboard) menu.current = row.index
                onClicked: menu.activate(row.r)
              }
            }
          }
        }
      }
    }
  }
}
