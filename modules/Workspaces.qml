import QtQuick
import "../bridge" as Bridge
import ".." as Root
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Workspaces (and optionally the Omarchy menu logo) in one compact module.
// Loaded by the Amiga Bar as a custom QML module:
//   { "id": "amiga.workspaces", "source": ".../modules/Workspaces.qml",
//     "variant": "pips" | "stack" | "logo" | "minimap" | "cli" | "boing"
//                | "none" (menu logo only, next to the native workspaces),
//     "menu": true, "logo": "omarchy" | "amiga" | "boing" }
// Left click on a workspace focuses it. On the logo, with the "menu" option
// "drop" (default): left click folds out the drop-down menu (DropMenu.qml),
// right click opens Omarchy's own centred menu; with "strip": left click the
// Omarchy menu, right click the Amiga menu strip. Middle click: the Control
// Center. The mouse wheel steps through workspaces in every variant.
// The drop-down also answers the questions of the actions it ran
// (dropAsk, for the engine's IPC `ask`).
Item {
  id: root

  property var bar: null
  property string moduleName: "amiga.workspaces"
  property var settings: ({})

  function setting(key, fallback) {
    var v = settings ? settings[key] : undefined
    return v === undefined || v === null ? fallback : v
  }

  readonly property string variant: String(setting("variant", "pips"))
  readonly property bool showMenu: setting("menu", true) !== false
  readonly property string logo: String(setting("logo", "omarchy"))
  readonly property int barSize: bar && bar.barSize ? bar.barSize : Style.bar.sizeHorizontal
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : Color.bar.text
  readonly property color accent: Color.accent
  // Theme material `tones.strong` (Tusche & Papier): the bar's text is the
  // quieter tone there; logo and the active workspace's number stay strong
  readonly property color strong: Bridge.ModuleBus.material && Bridge.ModuleBus.material.tones && Bridge.ModuleBus.material.tones.strong
    ? Qt.color(Bridge.ModuleBus.material.tones.strong) : fg
  readonly property color urgentColor: Color.urgent
  readonly property color dim: Util.alpha(fg, 0.45)

  // ---------------------------------------------------------------- data
  readonly property var workspaces: Hyprland.workspaces.values
  readonly property int active: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

  function byId(id) {
    for (var i = 0; i < workspaces.length; i++) if (workspaces[i].id === id) return workspaces[i]
    return null
  }
  function windows(id) { var w = byId(id); return w && w.toplevels ? w.toplevels.values.length : 0 }
  function occupied(id) { return windows(id) > 0 }
  function urgent(id) { var w = byId(id); return !!(w && w.urgent === true) }

  // 1–5 always, plus live ones up to 10 (like the native widget).
  readonly property var ids: {
    var list = [1, 2, 3, 4, 5]
    for (var i = 0; i < workspaces.length; i++) {
      var id = workspaces[i].id
      if (id > 0 && id <= 10 && list.indexOf(id) === -1) list.push(id)
    }
    return list.sort(function(a, b) { return a - b })
  }
  readonly property var occupiedIds: ids.filter(function(id) { return occupied(id) || id === active })

  // Position of the active workspace in `ids`; the marker glides to it
  // (Style.duration returns 0 with Reduced Motion, so it jumps).
  readonly property int activeIndex: Math.max(0, ids.indexOf(active))
  property real activeF: activeIndex
  Behavior on activeF { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }

  function focusWorkspace(id) {
    if (bar) bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }
  function step(delta) {
    var i = ids.indexOf(active)
    var next = ids[Math.max(0, Math.min(ids.length - 1, (i < 0 ? 0 : i) + delta))]
    if (next !== active) focusWorkspace(next)
  }
  readonly property bool dropStyle: Bridge.ModuleBus.menuStyle !== "strip"
  function openMenu(button) {
    if (!bar) return
    if (button === Qt.MiddleButton) bar.run("omarchy-shell amiga-bar options")
    else if (dropStyle && button !== Qt.RightButton) toggleDrop()
    else if (!dropStyle && button === Qt.RightButton) bar.run("omarchy-shell amiga-bar strip")
    else bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
  }

  // ---------------------------------------------------------------- drop-down menu
  // Popup contract for the panel and the bar's single-popout coordinator.
  // Only with the logo shown and the "drop" option; otherwise open() is a
  // no-op, so panel navigation never holds an invisible "opened" owner.
  readonly property bool dropAvailable: showMenu && dropStyle && !!bar
  property bool dropOpen: false
  readonly property bool opened: dropOpen
  property bool popoutSwitchClosing: false
  function open() { if (dropAvailable) dropOpen = true }
  function close() { dropOpen = false }
  function closeForPopoutSwitch() { popoutSwitchClosing = true; dropOpen = false; Qt.callLater(function() { root.popoutSwitchClosing = false }) }
  function toggleDrop() { if (dropOpen) close(); else open() }
  function syncDrop() { if (Bridge.ModuleBus.engine) Bridge.ModuleBus.engine.syncDropMenu() }
  onDropOpenChanged: syncDrop()
  // Close (and so release the bar's popout) before the panel goes away.
  onDropAvailableChanged: if (!dropAvailable) close()

  // The logo as a bar click target: with a popup open, the panel covers the
  // bar and forwards clicks only to registered targets.
  property var registeredBar: null
  function syncClickRegistration() {
    if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(menuSlot)
    registeredBar = root.bar
    if (registeredBar && registeredBar.registerClickTarget) registeredBar.registerClickTarget(menuSlot)
  }
  onBarChanged: syncClickRegistration()
  Component.onCompleted: { Bridge.ModuleBus.register("workspaces", root); syncClickRegistration() }
  Component.onDestruction: {
    dropOpen = false
    if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(menuSlot)
    Bridge.ModuleBus.unregister("workspaces", root); syncDrop()
  }

  Loader {
    id: dropLoader
    active: root.dropAvailable || root.dropOpen
    sourceComponent: Component {
      Root.DropMenu {
        anchorItem: menuSlot
        owner: root
        bar: root.bar
        open: root.dropOpen
      }
    }
  }

  // Questions from the menu shims (bin/menu-shim, through the engine's IPC
  // `ask`): this screen's drop-down answers them and opens for them.
  function dropTracks(token) { var m = dropLoader.item; return !!m && m.tracks(token) }
  function dropAsk(request) {
    var m = dropLoader.item
    if (!dropAvailable || !m || !m.takeRequest(request)) return false
    if (m.hasPending()) open()
    return true
  }
  function dropState() {
    var m = dropLoader.item
    return m ? { requests: m.requests.length, launches: m.launches.length } : null
  }

  readonly property real menuWidth: showMenu ? barSize + Style.space(4) : 0
  implicitHeight: barSize
  implicitWidth: menuWidth + (loader.item ? loader.item.implicitWidth : 0) + Style.space(6)

  // ---------------------------------------------------------------- menu logo
  Item {
    id: menuSlot
    visible: root.showMenu
    function triggerPress(button) { root.openMenu(button) }
    width: root.menuWidth
    height: root.barSize

    // Theme material (edge "theme"): while the drop menu is open the logo is
    // its source – an inverted block from just under the bar's top down to
    // its lower edge, where the menu card hangs from it.
    readonly property var source: Bridge.ModuleBus.material ? Bridge.ModuleBus.material.source || null : null
    readonly property bool inverted: !!source && root.dropOpen
    Rectangle {
      visible: menuSlot.inverted
      y: Math.round(root.barSize * 0.17)
      width: parent.width
      height: parent.height - y
      color: menuSlot.source ? menuSlot.source.fill : "transparent"
    }

    Text { renderType: Text.NativeRendering;
      anchors.centerIn: parent
      anchors.verticalCenterOffset: menuSlot.inverted ? Math.round(root.barSize * 0.08) : 0
      visible: root.variant !== "logo" && root.logo === "omarchy"
      text: ""
      font.family: Bridge.ModuleBus.pixelAll ? Bridge.ModuleBus.pixelFamily : "omarchy"
      font.pixelSize: Bridge.ModuleBus.px(Style.font.icon + 2)
      color: menuSlot.inverted ? menuSlot.source.text : root.strong
    }

    // Amiga tick or Boing ball in the pixel brick grid, on whole pixels.
    PixelLogo {
      visible: root.variant !== "logo" && root.logo !== "omarchy"
      kind: root.logo
      x: Math.round((parent.width - implicitWidth) / 2)
      y: Math.round((parent.height - implicitHeight) / 2)
      width: implicitWidth; height: implicitHeight
    }

    // "logo": the frame carries the active workspace number.
    Item {
      anchors.centerIn: parent
      visible: root.variant === "logo"
      width: Math.round(root.barSize * 0.68); height: width
      Rectangle { anchors.fill: parent; color: "transparent"; border.width: Math.max(1, Style.space(1.5)); border.color: root.strong; radius: Math.min(Style.cornerRadius, 3) }
      Text { renderType: Text.NativeRendering;
        anchors.centerIn: parent
        text: root.active === 10 ? "0" : String(root.active)
        font.family: Bridge.ModuleBus.family; font.bold: true
        font.pixelSize: Bridge.ModuleBus.px(Style.font.body + 1)
        color: root.accent
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor
      onClicked: function(m) { root.openMenu(m.button) }
    }
  }

  // ---------------------------------------------------------------- workspaces
  Loader {
    id: loader
    x: root.menuWidth
    height: root.barSize
    sourceComponent: {
      switch (root.variant) {
      case "stack": return stackView
      case "logo": return dotsView
      case "minimap": return minimapView
      case "cli": return cliView
      case "boing": return boingView
      case "none": return null
      default: return pipsView
      }
    }
  }

  // Wheel anywhere on the module steps workspaces.
  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: function(e) { root.step(e.angleDelta.y > 0 ? -1 : 1) }
  }

  // Pips: 8 px squares; hovering grows them into numbered chips.
  Component {
    id: pipsView
    Item {
      id: pips
      readonly property real h: hover.hovered ? 1 : 0
      property real grow: h
      Behavior on grow { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
      readonly property real cell: Style.space(8) + (Style.space(20) - Style.space(8)) * grow
      readonly property real gap: Style.space(5) - Style.space(2) * grow
      implicitWidth: root.ids.length * cell + (root.ids.length - 1) * gap
      height: root.barSize
      HoverHandler { id: hover }

      Repeater {
        model: root.ids
        Item {
          required property int modelData
          required property int index
          readonly property bool occ: root.occupied(modelData)
          readonly property bool urg: root.urgent(modelData)
          x: index * (pips.cell + pips.gap)
          width: pips.cell
          height: root.barSize
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Style.space(8) + Style.space(8) * pips.grow
            color: parent.urg ? root.urgentColor : parent.occ ? Util.alpha(root.fg, 0.5) : "transparent"
            border.width: parent.occ || parent.urg ? 0 : 1
            border.color: root.dim
            radius: Math.min(Style.cornerRadius, 2)
          }
          Text { renderType: Text.NativeRendering;
            anchors.centerIn: parent
            opacity: pips.grow
            text: modelData === 10 ? "0" : String(modelData)
            font.family: Bridge.ModuleBus.family; font.bold: true; font.pixelSize: Bridge.ModuleBus.px(Style.font.bodySmall)
            color: parent.occ ? Bridge.ModuleBus.barColor : root.fg
          }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.focusWorkspace(parent.modelData) }
        }
      }

      // active marker + rule underneath
      Rectangle {
        x: root.activeF * (pips.cell + pips.gap) - 1
        anchors.verticalCenter: parent.verticalCenter
        width: pips.cell + 2
        height: Style.space(8) + Style.space(8) * pips.grow + 2
        color: root.accent
        radius: Math.min(Style.cornerRadius, 2)
        Text { renderType: Text.NativeRendering;
          anchors.centerIn: parent
          opacity: pips.grow
          text: root.active === 10 ? "0" : String(root.active)
          font.family: Bridge.ModuleBus.family; font.bold: true; font.pixelSize: Bridge.ModuleBus.px(Style.font.bodySmall)
          color: Bridge.ModuleBus.barColor
        }
      }
      Rectangle {
        x: root.activeF * (pips.cell + pips.gap) - 1
        y: root.barSize - Style.space(5)
        width: pips.cell + 2; height: Math.max(1, Style.space(2))
        color: Util.alpha(root.accent, 0.8)
      }
    }
  }

  // Stack: the active workspace in front, occupied ones stacked behind.
  Component {
    id: stackView
    Item {
      readonly property var others: root.occupiedIds.filter(function(id) { return id !== root.active }).slice(0, 3)
      readonly property real box: Math.round(root.barSize * 0.6)
      implicitWidth: box + others.length * Style.space(4) + Style.space(2)
      height: root.barSize
      Repeater {
        model: parent.others.length
        Rectangle {
          required property int index
          readonly property int n: parent.others.length - index
          x: n * Style.space(4)
          y: (root.barSize - parent.box) / 2 - n * Style.space(2) + Style.space(2)
          width: parent.box; height: parent.box
          color: Bridge.ModuleBus.barColor
          border.width: 1
          border.color: root.urgent(parent.others[n - 1]) ? root.urgentColor : root.dim
          z: -n
        }
      }
      Rectangle {
        y: (root.barSize - parent.box) / 2 + Style.space(2)
        width: parent.box; height: parent.box
        color: Bridge.ModuleBus.barColor
        border.width: Math.max(1, Style.space(1.5)); border.color: root.accent
        Text { renderType: Text.NativeRendering; anchors.centerIn: parent; text: root.active === 10 ? "0" : String(root.active); font.family: Bridge.ModuleBus.family; font.bold: true; font.pixelSize: Bridge.ModuleBus.px(Style.font.body); color: root.strong }
      }
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        // Click brings the next occupied (urgent first) to the front.
        onClicked: function(m) {
          var o = parent.others
          var u = o.filter(function(id) { return root.urgent(id) })
          if (u.length) root.focusWorkspace(u[0])
          else if (o.length) root.focusWorkspace(m.button === Qt.RightButton ? o[o.length - 1] : o[0])
        }
      }
    }
  }

  // Logo variant: five dots next to the numbered logo.
  Component {
    id: dotsView
    Item {
      readonly property real dot: Style.space(5)
      implicitWidth: root.ids.length * (dot + Style.space(2))
      height: root.barSize
      Repeater {
        model: root.ids
        Rectangle {
          required property int modelData
          required property int index
          x: index * (parent.dot + Style.space(2))
          anchors.verticalCenter: parent.verticalCenter
          width: parent.dot; height: parent.dot
          color: modelData === root.active ? root.accent : root.urgent(modelData) ? root.urgentColor : root.occupied(modelData) ? root.fg : root.dim
          opacity: root.occupied(modelData) || modelData === root.active ? 1 : 0.6
          MouseArea { anchors.fill: parent; anchors.margins: -2; cursorShape: Qt.PointingHandCursor; onClicked: root.focusWorkspace(parent.modelData) }
        }
      }
    }
  }

  // Minimap: occupied workspaces only, one column per window.
  Component {
    id: minimapView
    Row {
      spacing: Style.space(4)
      height: root.barSize
      Repeater {
        model: root.occupiedIds
        Rectangle {
          required property int modelData
          readonly property bool act: modelData === root.active
          readonly property int n: Math.max(1, root.windows(modelData))
          anchors.verticalCenter: parent.verticalCenter
          width: Math.round(root.barSize * 0.9); height: Math.round(root.barSize * 0.6)
          color: Bridge.ModuleBus.barLight ? Qt.darker(Bridge.ModuleBus.barColor, act ? 1.04 : 1.16)
                 : act ? Qt.lighter(Bridge.ModuleBus.barColor, 1.6) : Qt.darker(Bridge.ModuleBus.barColor, 1.3)
          border.width: act ? Math.max(1, Style.space(1.5)) : 1
          border.color: root.urgent(modelData) ? root.urgentColor : act ? root.accent : root.dim
          Row {
            anchors.fill: parent; anchors.margins: 3; spacing: 1
            Repeater {
              model: parent.parent.n
              Rectangle {
                width: (parent.width - (parent.parent.n - 1)) / parent.parent.n
                height: parent.height
                color: Util.alpha(root.fg, parent.parent.act ? 0.7 : 0.4)
              }
            }
          }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.focusWorkspace(parent.modelData) }
        }
      }
    }
  }

  // CLI: "2>" like the Kickstart 1.3 shell prompt, block cursor, +n others.
  Component {
    id: cliView
    Row {
      spacing: Style.space(2)
      height: root.barSize
      Text { renderType: Text.NativeRendering;
        anchors.verticalCenter: parent.verticalCenter
        text: (root.active === 10 ? "0" : String(root.active)) + ">"
        font.family: Bridge.ModuleBus.family; font.bold: true; font.pixelSize: Bridge.ModuleBus.px(Style.font.body + 1)
        color: root.strong
      }
      Rectangle {
        id: cursor
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(8); height: Math.round(root.barSize * 0.55)
        color: root.accent
        SequentialAnimation on opacity {
          running: !Style.reduceMotion
          loops: Animation.Infinite
          NumberAnimation { to: 1; duration: 0 }
          PauseAnimation { duration: 600 }
          NumberAnimation { to: 0.15; duration: 0 }
          PauseAnimation { duration: 400 }
        }
      }
      Text { renderType: Text.NativeRendering;
        readonly property int others: root.occupiedIds.filter(function(id) { return id !== root.active }).length
        visible: others > 0
        anchors.verticalCenter: parent.verticalCenter
        text: "+" + others
        font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.caption)
        color: root.dim
      }
    }
  }

  // Boing: a ball rolls along a track to the active workspace.
  Component {
    id: boingView
    Item {
      readonly property real stepW: Style.space(13)
      implicitWidth: (root.ids.length - 1) * stepW + Style.space(12)
      height: root.barSize
      Rectangle { x: 0; y: root.barSize * 0.72; width: parent.implicitWidth; height: 1; color: root.dim }
      Repeater {
        model: root.ids
        Rectangle {
          required property int modelData
          required property int index
          readonly property bool occ: root.occupied(modelData)
          x: Style.space(6) + index * parent.stepW - 1
          y: root.barSize * 0.72 - height
          width: 2; height: occ ? Style.space(4) : Style.space(2)
          color: root.urgent(modelData) ? root.urgentColor : occ ? root.fg : root.dim
          MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: root.focusWorkspace(parent.modelData) }
        }
      }
      BoingBall {
        size: Math.round(root.barSize * 0.42)
        x: Style.space(6) + root.activeF * parent.stepW - size / 2
        y: root.barSize * 0.72 - size - 1
        spin: root.activeF * 2.2
      }
    }
  }
}
