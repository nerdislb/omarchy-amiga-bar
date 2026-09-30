import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import "Presets.js" as Presets

// Intuition menu strip: like holding the right mouse button on the Amiga
// screen title, the bar turns into a menu strip (inverted colours) with
// drop-down menus. Opened from the Omarchy logo (right click) or Super+Alt+M.
// Moving over a title switches menus; arrows/Enter/Esc work too.
PanelWindow {
  id: win

  property var host: null
  property bool open: false
  signal closeRequested()

  readonly property var menus: host ? host.menuModel() : []
  property int current: 0
  property int item: -1
  onItemChanged: {
    var child = itemRepeater.itemAt(item)
    if (!child || item < 0) return
    if (child.y < menuScroll.contentY) menuScroll.contentY = child.y
    else if (child.y + child.height > menuScroll.contentY + menuScroll.height)
      menuScroll.contentY = child.y + child.height - menuScroll.height
  }
  property bool pointerKnown: false
  property real pointerX: 0
  property real pointerY: 0
  // Delegate creation/relayout may generate hover events without physical
  // motion. Do not let those steal selection from keyboard navigation.
  function pointerMoved(area, mouse) {
    var p = area.mapToItem(win.contentItem, mouse.x, mouse.y)
    var moved = pointerKnown && (Math.abs(p.x - pointerX) > 0.5 || Math.abs(p.y - pointerY) > 0.5)
    pointerKnown = true; pointerX = p.x; pointerY = p.y
    return moved
  }
  onOpenChanged: if (open) { current = 0; item = -1; pointerKnown = false }
  onCurrentChanged: { item = -1; menuScroll.contentY = 0 }

  readonly property bool topaz: host && host.options.font === "topaz"
  readonly property color stripBg: Color.bar.text
  readonly property color stripInk: Color.bar.background
  readonly property int barH: Style.bar.sizeHorizontal

  screen: {
    var s = Quickshell.screens, f = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    for (var i = 0; i < s.length; i++) if (s[i].name === f) return s[i]
    return s.length ? s[0] : null
  }
  visible: open
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "amiga-bar-menu"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  function trigger(entry) {
    if (!entry || entry.separator || entry.disabled) return
    win.closeRequested()
    if (typeof entry.action === "function") Qt.callLater(entry.action)
  }

  FontLoader { id: topazFont; source: "file://" + (win.host ? win.host.pluginDir : "") + "/assets/fonts/nerdworkbench/NerdWorkbenchUI-Regular.ttf" }

  component Label: Text { textFormat: Text.PlainText;
    font.family: win.topaz && topazFont.status === FontLoader.Ready ? topazFont.name : Style.font.family
    font.pixelSize: win.topaz ? 16 : Style.font.body
    renderType: Text.NativeRendering
    transform: Scale { xScale: 1 }
    // Scale does not change the layout width; make room for it.
    readonly property real layoutWidth: implicitWidth * (1)
  }

  MouseArea {
    anchors.fill: parent; hoverEnabled: true
    onPositionChanged: function(mouse) { win.pointerMoved(this, mouse) }
    onClicked: win.closeRequested()
  }

  Item {
    id: keys
    anchors.fill: parent
    focus: win.open
    Keys.onPressed: function(e) {
      var m = win.menus[win.current]
      if (e.key === Qt.Key_Escape) { win.closeRequested(); e.accepted = true }
      else if (e.key === Qt.Key_Left) { win.current = (win.current + win.menus.length - 1) % win.menus.length; win.item = -1; e.accepted = true }
      else if (e.key === Qt.Key_Right) { win.current = (win.current + 1) % win.menus.length; win.item = -1; e.accepted = true }
      else if ((e.key === Qt.Key_Down || e.key === Qt.Key_Up) && m) {
        var n = m.items.length, step = e.key === Qt.Key_Down ? 1 : -1, i = win.item
        for (var k = 0; k < n; k++) { i = (i + step + n) % n; if (!m.items[i].separator && !m.items[i].disabled) break }
        win.item = i; e.accepted = true
      }
      else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && m && win.item >= 0) { win.trigger(m.items[win.item]); e.accepted = true }
    }
  }

  // ---- the strip over the bar
  Rectangle {
    id: strip
    width: parent.width
    height: win.barH
    color: win.stripBg
    MouseArea { anchors.fill: parent }
    Row {
      id: titles
      x: Style.space(12)
      height: parent.height
      Repeater {
        // A numeric model keeps title delegates alive across state refreshes.
        id: titleRepeater
        model: win.menus.length
        Rectangle {
          id: title
          required property int index
          readonly property var modelData: win.menus[index] || ({})
          readonly property bool hot: win.current === index
          width: tl.layoutWidth + Style.space(24)
          height: strip.height
          color: hot ? Color.accent : "transparent"
          Label { id: tl; x: Style.space(12); anchors.verticalCenter: parent.verticalCenter; text: title.modelData.title; color: title.hot ? Color.bar.background : win.stripInk }
          MouseArea {
            anchors.fill: parent; hoverEnabled: true
            onPositionChanged: function(mouse) { if (win.pointerMoved(this, mouse)) win.current = title.index }
            onClicked: { win.current = title.index; win.item = -1 }
          }
        }
      }
    }
    Label {
      anchors.right: parent.right; anchors.rightMargin: Style.space(12); anchors.verticalCenter: parent.verticalCenter
      width: layoutWidth
      text: "Amiga Bar"
      color: Util.alpha(win.stripInk, 0.55)
      transformOrigin: Item.Right
    }
  }

  // ---- the open menu
  Rectangle {
    id: drop
    readonly property var menu: win.menus[win.current] || null
    readonly property Item anchorTitle: titleRepeater.itemAt(win.current)
    x: Math.min(anchorTitle ? titles.x + anchorTitle.x : 0, win.width - width - Style.space(4))
    y: strip.height
    width: Math.min(win.width - Style.space(8), Math.max(Style.space(300), Math.min(Style.space(820),
      menu ? menu.items.reduce(function(w, e) {
        return Math.max(w, Math.min(48, String(e.label || "").length) * (win.topaz ? 14 : Style.font.body * 0.66)
          + String(e.note || "").length * Style.font.caption * 0.66 + Style.space(80))
      }, 0) : 0)))
    height: Math.min(win.height - y - Style.space(8), list.implicitHeight + Style.space(8))
    color: win.stripBg
    border.width: 1
    border.color: win.stripInk
    visible: !!menu
    MouseArea { anchors.fill: parent }

    Flickable {
      id: menuScroll
      anchors.fill: parent; anchors.margins: Style.space(4)
      clip: true; contentHeight: list.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
    Column {
      id: list
      width: menuScroll.width
      Repeater {
        id: itemRepeater
        model: drop.menu ? drop.menu.items.length : 0
        Item {
          id: row
          required property int index
          readonly property var modelData: drop.menu && drop.menu.items[index] ? drop.menu.items[index] : ({})
          readonly property bool hot: win.item === index && !modelData.separator && !modelData.disabled
          width: list.width
          implicitWidth: rowContent.implicitWidth + Style.space(60)
          height: modelData.separator ? Style.space(9) : Math.max(Style.space(24), rl.implicitHeight + Style.space(6))

          // dotted separator, like Workbench
          Row {
            visible: row.modelData.separator === true
            anchors.verticalCenter: parent.verticalCenter
            x: Style.space(6)
            spacing: Style.space(2)
            Repeater { model: Math.floor((list.width - Style.space(12)) / Style.space(4)); Rectangle { width: Style.space(2); height: 1; color: Util.alpha(win.stripInk, 0.6) } }
          }

          Rectangle { anchors.fill: parent; visible: row.hot; color: Color.accent }

          Row {
            id: rowContent
            width: row.width - accessories.implicitWidth - Style.space(28)
            visible: !row.modelData.separator
            anchors.verticalCenter: parent.verticalCenter
            x: Style.space(6)
            spacing: Style.space(6)
            Text { textFormat: Text.PlainText;
              width: Style.space(14)
              anchors.verticalCenter: parent.verticalCenter
              text: row.modelData.checked ? "✓" : ""
              font.family: Style.font.family; font.bold: true; font.pixelSize: Style.font.body
              color: row.hot ? Color.bar.background : win.stripInk
            }
            Label {
              id: rl
              anchors.verticalCenter: parent.verticalCenter
              width: Math.max(0, (rowContent.width - Style.space(20)) / (1))
              elide: Text.ElideRight
              text: row.modelData.label || ""
              color: row.hot ? Color.bar.background : win.stripInk
              opacity: row.modelData.disabled ? 0.45 : 1
            }
          }
          Row {
            id: accessories
            visible: !row.modelData.separator
            anchors.right: parent.right; anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)
            Text { textFormat: Text.PlainText;
              visible: !!row.modelData.note
              anchors.verticalCenter: parent.verticalCenter
              text: row.modelData.note || ""
              font.family: Style.font.family; font.pixelSize: Style.font.caption
              color: row.hot ? Color.bar.background : Util.alpha(win.stripInk, 0.7)
            }
            // Amiga key (= Super) shortcut hint
            Row {
              visible: !!row.modelData.key
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(3)
              Rectangle {
                width: Style.space(14); height: width
                color: "transparent"; border.width: 1; border.color: row.hot ? Color.bar.background : win.stripInk
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "A"; font.family: Style.font.family; font.bold: true; font.pixelSize: Style.font.caption - 1; color: row.hot ? Color.bar.background : win.stripInk }
              }
              Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.key || ""; font.family: Style.font.family; font.bold: true; font.pixelSize: Style.font.caption; color: row.hot ? Color.bar.background : win.stripInk }
            }
          }

          MouseArea {
            anchors.fill: parent
            enabled: !row.modelData.separator && !row.modelData.disabled
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onPositionChanged: function(mouse) { if (win.pointerMoved(this, mouse)) win.item = row.index }
            onClicked: win.trigger(row.modelData)
          }
        }
      }
    }
      }
}
}
