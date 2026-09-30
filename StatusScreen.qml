import QtQuick
import "bridge" as Bridge
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui as Ui

// Status screen: an Amiga "screen behind the Workbench", pulled down over
// the desktop with Super+M (Amiga-M) or the Tools menu. Six tiles: agents,
// tests, AI quotas, phone, today, system/network. Esc, Super+M or the depth
// gadget send it back. Reduced Motion fades instead of sliding.
PanelWindow {
  id: win

  property var host: null
  property bool open: false
  signal closeRequested()

  readonly property var sys: host ? host.sys : null

  screen: {
    var s = Quickshell.screens, f = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    for (var i = 0; i < s.length; i++) if (s[i].name === f) return s[i]
    return s.length ? s[0] : null
  }
  visible: open || slide.progress > 0.001
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "amiga-bar-screen"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  QtObject {
    id: slide
    property real progress: win.open ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Style.duration(260); easing.type: Easing.OutCubic } }
  }

  function timeText(ms) { return Qt.formatDateTime(new Date(ms), "HH:mm") }
  function resetText(iso) {
    var ms = Date.parse(iso) - Date.now(); if (!(ms > 0)) return ""
    var m = Math.round(ms / 60000), h = Math.floor(m / 60)
    return h >= 48 ? Math.floor(h / 24) + " d" : h > 0 ? h + " h " + (m % 60) + " min" : m + " min"
  }

  Rectangle {
    id: sheet
    width: parent.width
    height: parent.height
    // Slides down from above; with Reduced Motion it only fades.
    y: Style.reduceMotion ? 0 : -height * (1 - slide.progress)
    opacity: Style.reduceMotion ? slide.progress : 1
    color: Qt.darker(Color.popups.background, 1.25)

    Item {
      id: keys
      anchors.fill: parent
      focus: win.open
      Keys.onPressed: function(e) {
        if (e.key === Qt.Key_Escape || (e.key === Qt.Key_M && (e.modifiers & Qt.MetaModifier))) { win.closeRequested(); e.accepted = true }
      }
    }

    // Screen title bar
    Rectangle {
      id: titleBar
      width: parent.width
      height: Style.bar.sizeHorizontal
      color: Color.bar.text
      Text { textFormat: Text.PlainText;
        x: Style.space(14); anchors.verticalCenter: parent.verticalCenter
        text: "Omarchy status screen  ·  Amiga-M"
        font.family: Bridge.ModuleBus.momentFamily
        font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.body)
        font.bold: !Bridge.ModuleBus.pixelMoments
        renderType: Text.NativeRendering
        color: Color.bar.background
      }
      Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
        anchors.right: gadget.left; anchors.rightMargin: Style.space(14); anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDateTime(clock.date, "dddd, d. MMMM · HH:mm") + "   ·   Super+M / Esc to go back"
        font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.caption)
        color: Util.alpha(Color.bar.background, 0.7)
      }
      // Depth gadget: front/back
      Item {
        id: gadget
        anchors.right: parent.right
        width: parent.height; height: parent.height
        Rectangle { x: parent.width * 0.2; y: parent.height * 0.2; width: parent.width * 0.42; height: parent.height * 0.38; color: "transparent"; border.width: 1; border.color: Color.bar.background }
        Rectangle { x: parent.width * 0.38; y: parent.height * 0.42; width: parent.width * 0.42; height: parent.height * 0.38; color: Color.bar.background }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.closeRequested() }
      }
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }

    Grid {
      id: grid
      x: Style.space(24); y: titleBar.height + Style.space(24)
      columns: 3
      spacing: Style.space(18)
      readonly property real tileW: (sheet.width - Style.space(48) - spacing * 2) / 3
      readonly property real tileH: (sheet.height - titleBar.height - Style.space(48) - spacing) / 2

      // ---- Agents
      Tile {
        title: "Agents"
        note: win.sys ? win.sys.agents.filter(function(a) { return a.status === "working" }).length + " working · "
                        + win.sys.agents.filter(function(a) { return a.status === "blocked" }).length + " waiting" : ""
        Column {
          width: parent.width
          spacing: Style.space(4)
          Repeater {
            model: win.sys ? win.sys.agents.slice().sort(function(a, b) {
              var o = { blocked: 0, working: 1, idle: 2 }; return (a.status in o ? o[a.status] : 3) - (b.status in o ? o[b.status] : 3) }).slice(0, 9) : []
            Rectangle {
              required property var modelData
              width: parent.width; height: Math.max(Style.space(34), Bridge.ModuleBus.pixelMoments ? 38 : 0)
              color: rowMouse.containsMouse ? Util.alpha(Color.popups.text, 0.08) : "transparent"
              Rectangle { width: Style.space(3); height: parent.height - Style.space(8); anchors.verticalCenter: parent.verticalCenter
                color: modelData.status === "blocked" ? Color.accent : modelData.status === "working" ? (Color.popups.border || Color.accent) : Util.alpha(Color.popups.text, 0.2) }
              Column {
                x: Style.space(12); anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(90)
                spacing: Bridge.ModuleBus.pixelMoments ? 2 : 0   // pixel lines carry no leading
                Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; width: parent.width; elide: Text.ElideRight; text: modelData.title || modelData.agent; font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.body); color: Color.popups.text }
                Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; text: (modelData.agent || "") + (modelData.project ? " · " + modelData.project : ""); font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.caption); color: Util.alpha(Color.popups.text, 0.55) }
              }
              Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
                anchors.right: parent.right; anchors.rightMargin: Style.space(8); anchors.verticalCenter: parent.verticalCenter
                text: modelData.status === "blocked" ? "waiting" : modelData.status === "working" ? "working" : "idle"
                font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.caption); font.bold: modelData.status === "blocked"
                color: modelData.status === "blocked" ? Color.accent : Util.alpha(Color.popups.text, 0.6)
              }
              MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { win.closeRequested(); win.host.focusAgent(parent.modelData) } }
            }
          }
          Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; visible: win.sys && win.sys.agents.length === 0; text: "No agents reported (herdr/Flux)"; font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.body); color: Util.alpha(Color.popups.text, 0.55) }
        }
      }

      // ---- Tests
      Tile {
        title: "Tests · nbtiles"
        note: win.sys && win.sys.tests ? win.sys.tests.run : ""
        Column {
          width: parent.width
          spacing: Style.space(8)
          Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
            text: !win.sys || !win.sys.tests ? "No run yet" : win.sys.tests.stale ? "interrupted?" : win.sys.tests.running ? "running …" : (win.sys.tests.failed ? "finished · with failures" : "finished · green")
            font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.title); font.bold: true
            color: win.sys && win.sys.tests && !win.sys.tests.running ? (win.sys.tests.failed ? Color.urgent : Color.popups.text) : Color.accent
          }
          Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
            width: parent.width; wrapMode: Text.WordWrap
            text: !win.sys || !win.sys.tests ? "" : (win.sys.tests.lastOut ? "last output " + Qt.formatDateTime(new Date(win.sys.tests.lastOut), "HH:mm") + "\n" : "")
                  + String(win.sys.tests.summary).replace(/;/g, "\n")
            font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.body); color: Util.alpha(Color.popups.text, 0.8)
          }
          Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; text: "nbtiles-test <worktree> starts a run"; font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.caption); color: Util.alpha(Color.popups.text, 0.45) }
        }
      }

      // ---- AI quotas
      Tile {
        title: "AI quotas"
        Column {
          width: parent.width
          spacing: Style.space(10)
          Repeater {
            model: win.sys ? win.sys.quotas : []
            Column {
              required property var modelData
              width: parent.width
              spacing: Style.space(3)
              Row {
                width: parent.width
                Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; width: parent.width * 0.6; elide: Text.ElideRight; text: modelData.name + " · " + modelData.label; font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.body); color: Color.popups.text }
                Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; width: parent.width * 0.4; horizontalAlignment: Text.AlignRight
                  text: modelData.percent >= 0 ? Math.round(modelData.percent * 100) + " %" + (win.resetText(modelData.resetsAt) ? " · " + win.resetText(modelData.resetsAt) : "") : modelData.value
                  font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.caption); color: Util.alpha(Color.popups.text, 0.7) }
              }
              // tracker-style segments
              Row {
                visible: modelData.percent >= 0
                spacing: 2
                Repeater {
                  model: 24
                  Rectangle {
                    required property int index
                    width: (grid.tileW - Style.space(40) - 46) / 24; height: Style.space(8)
                    color: parent.parent.modelData.percent * 24 > index ? (index >= 21 ? Color.urgent : index >= 15 ? Color.accent : (Color.popups.border || Color.accent))
                                                                       : Util.alpha(Color.popups.text, 0.1)
                  }
                }
              }
            }
          }
        }
      }

      // ---- Phone
      Tile {
        title: win.sys && win.sys.phone ? win.sys.phone.name : "Phone"
        note: win.sys && win.sys.phone ? (win.sys.phone.online ? "connected · Flux" : "offline") : "not paired"
        Column {
          width: parent.width
          spacing: Style.space(10)
          Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
            text: win.sys && win.sys.phone && win.sys.phone.charge >= 0 ? win.sys.phone.charge + " %" : "–"
            font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.displayLarge); font.bold: true; color: Color.popups.text
          }
          Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
            text: win.sys && win.sys.phone && win.sys.phone.charging ? "charging" : ""
            font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.body); color: Color.accent
          }
          Row {
            spacing: Style.space(10)
            TileButton { label: "Open Flux"; onPicked: win.host.run("omarchy-shell shell toggle flux") }
            TileButton { label: "WhatsApp"; onPicked: win.host.run("omarchy-shell io.github.moizibnyousaf.omawhatsapp toggleDropdown") }
          }
        }
      }

      // ---- Today
      Tile {
        title: "Today & tomorrow"
        note: "OmaMail-Kalender"
        Column {
          width: parent.width
          spacing: Style.space(6)
          Repeater {
            model: win.sys ? win.sys.events : []
            Row {
              required property var modelData
              width: parent.width
              spacing: Style.space(10)
              Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
                width: Style.space(90)
                text: modelData.allDay ? "all day" : (new Date(modelData.start).toDateString() === new Date().toDateString() ? "" : Qt.formatDateTime(new Date(modelData.start), "ddd ")) + win.timeText(modelData.start)
                font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.body); color: Color.accent
              }
              Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; width: parent.width - Style.space(100); elide: Text.ElideRight; text: modelData.title || "Event"; font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.body); color: Color.popups.text }
            }
          }
          Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; visible: win.sys && win.sys.events.length === 0; text: "Nothing else planned"; font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.body); color: Util.alpha(Color.popups.text, 0.55) }
        }
      }

      // ---- System & network
      Tile {
        title: "System & network"
        Column {
          width: parent.width
          spacing: Style.space(8)
          Repeater {
            model: win.sys ? [
              ["CPU", Math.round(win.sys.cpu * 100) + " %", win.sys.cpu > 0.85],
              ["Memory", Math.round(win.sys.mem * 100) + " %", win.sys.mem > 0.9],
              ["DH0:", win.sys.disk, false],
              ["WLAN", win.sys.wifiUp ? win.sys.wifiName : "disconnected", !win.sys.wifiUp],
              ["Proton VPN", win.sys.vpnUp ? "aktiv · " + win.sys.vpnName : "off", false],
              ["Tailscale", win.sys.tailscaleUp ? "online" : "off", false],
              ["Do not disturb", win.sys.dnd ? "an" : "off", false]
            ] : []
            Row {
              required property var modelData
              width: parent.width
              Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; width: parent.width * 0.4; text: modelData[0]; font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.body); color: Util.alpha(Color.popups.text, 0.6) }
              Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; width: parent.width * 0.6; elide: Text.ElideRight; text: modelData[1]; font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.body); color: modelData[2] ? Color.urgent : Color.popups.text }
            }
          }
        }
      }
    }
  }

  component Tile: Ui.BorderSurface {
    id: tile
    property string title: ""
    property string note: ""
    default property alias content: body.data
    width: grid.tileW
    height: grid.tileH
    color: Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
    padding: Style.spacing.popupPadding
    radius: Style.cornerRadius
    Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
      x: tile.contentLeftInset; y: tile.contentTopInset
      text: tile.title
      font.family: Bridge.ModuleBus.momentFamily; font.bold: true; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.title); color: Color.popups.text
    }
    Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
      anchors.right: parent.right; anchors.rightMargin: tile.contentRightInset; y: tile.contentTopInset + 2
      text: tile.note
      font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.caption); color: Util.alpha(Color.popups.text, 0.55)
    }
    Item {
      id: body
      x: tile.contentLeftInset; y: tile.contentTopInset + Style.space(30)
      width: tile.width - tile.contentLeftInset - tile.contentRightInset
      height: tile.height - y - tile.contentBottomInset
      clip: true
    }
  }

  component TileButton: Rectangle {
    id: tb
    property string label: ""
    signal picked()
    width: tbl.implicitWidth + Style.space(20); height: Style.space(30)
    radius: Style.cornerRadius
    color: tbm.containsMouse ? Style.hoverFillFor(Color.popups.text, Color.accent, Color.urgent) : Util.alpha(Color.popups.text, 0.06)
    border.width: 1; border.color: Util.alpha(Color.popups.text, 0.15)
    Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; id: tbl; anchors.centerIn: parent; text: tb.label; font.family: Bridge.ModuleBus.momentFamily; font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.body); color: Color.popups.text }
    MouseArea { id: tbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { win.closeRequested(); tb.picked() } }
  }
}
