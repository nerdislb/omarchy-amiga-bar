import QtQuick
import "../bridge" as Bridge
import ".." as Root
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The right side, compact. Custom QML module of the Tusche Bar:
//   { "id": "tusche.status", "source": ".../modules/Status.qml",
//     "variant": "groups" | "deviations", "embeds": { id: settings } }
//
// The widgets it replaces are mounted here, invisibly (`embeds`), so their
// own native popups (Wi-Fi list, Bluetooth devices, VPN map …) still open —
// from our group rows or the "more" list. Flux and the mail/WhatsApp widgets need
// their own services and are not embedded; Flux is read from its socket CLI
// and opened as its own window.
Item {
  id: root
  Component.onCompleted: { stableMountIds = mountIds; Bridge.ModuleBus.register("status", root) }
  Component.onDestruction: Bridge.ModuleBus.unregister("status", root)

  property var bar: null
  property string moduleName: "tusche.status"
  property var settings: ({})
  function setting(key, fallback) { var v = settings ? settings[key] : undefined; return v === undefined || v === null ? fallback : v }

  readonly property string variant: String(setting("variant", "groups"))
  readonly property var embeds: setting("embeds", {})
  readonly property int barSize: bar && bar.barSize ? bar.barSize : Style.bar.sizeHorizontal
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : Commons.Color.bar.text
  readonly property string home: Quickshell.env("HOME")
  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || (home + "/.local/share/omarchy")

  // ---------------------------------------------------------------- catalogue
  readonly property var catalogue: ({
    "omarchy.network": { name: "Wi-Fi / network", glyph: "\u{f0928}", file: "@/shell/plugins/panels/network/Panel.qml" },
    "io.github.iamfitsum.omarchy-proton-vpn": { name: "Proton VPN", glyph: "\u{f099d}", file: "~/.config/omarchy/plugins/io.github.iamfitsum.omarchy-proton-vpn/Panel.qml" },
    "omarchy.tailscale": { name: "Tailscale", glyph: "\u{f0570}", file: "@/shell/plugins/panels/tailscale/Panel.qml" },
    "omarchy.bluetooth": { name: "Bluetooth", glyph: "\u{f00af}", file: "@/shell/plugins/panels/bluetooth/Panel.qml" },
    "io.github.nerdislb.buds-control": { name: "Buds", glyph: "\u{f02cb}", file: "~/.config/omarchy/plugins/io.github.nerdislb.buds-control/BarWidget.qml" },
    "bitr0t.system-monitor": { name: "System monitor", glyph: "\u{f061a}", file: "~/.config/omarchy/plugins/bitr0t.system-monitor/BarWidget.qml" },
    "nerdibeard.monitor": { name: "Display & brightness", glyph: "\u{f0379}", file: "~/.config/omarchy/plugins/nerdibeard.monitor/Panel.qml" },
    "nerdibeard.googledrive": { name: "Google Drive", glyph: "\u{f02b6}", file: "~/.config/omarchy/plugins/nerdibeard.googledrive/Panel.qml" },
    "com.omastorm.radar": { name: "Rain radar", glyph: "\u{f0597}", file: "~/.config/omarchy/plugins/com.omastorm.radar/ui/RadarBar.qml" },
    "community.plugin-manager": { name: "Plugins", glyph: "\u{f03d7}", file: "~/.config/omarchy/plugins/community.plugin-manager/BarWidget.qml" },
    "flux": { name: "Flux · phone", glyph: "\u{f011c}", command: "omarchy-shell shell toggle flux" },
    "omarchy.power": { name: "Battery & power", glyph: "\u{f0079}", file: "@/shell/plugins/panels/power/Panel.qml" }
  })
  function filePath(f) {
    if (f.indexOf("@/") === 0) return "file://" + omarchyPath + f.substring(1)
    if (f.indexOf("~/") === 0) return "file://" + home + f.substring(1)
    return f
  }
  readonly property var embedIds: Object.keys(embeds || {}).filter(function(id) { return !!catalogue[id] })
  readonly property var mountIds: embedIds.filter(function(id) { return !!catalogue[id].file })
  // The Repeater only sees a new model when the set of ids changes; settings
  // edits (a folded widget saving its own options) are pushed into the live
  // widgets instead of rebuilding them, so their open popups stay open.
  property var stableMountIds: []
  onMountIdsChanged: if (JSON.stringify(mountIds) !== JSON.stringify(stableMountIds)) stableMountIds = mountIds

  readonly property var groups: [
    { id: "net", name: "Network", members: ["omarchy.network", "io.github.iamfitsum.omarchy-proton-vpn", "omarchy.tailscale", "omarchy.bluetooth"] },
    { id: "phone", name: "Phone", members: ["flux", "io.github.nerdislb.buds-control"] },
    { id: "system", name: "System", members: ["bitr0t.system-monitor", "nerdibeard.monitor", "nerdibeard.googledrive", "com.omastorm.radar", "community.plugin-manager"] }
  ]

  // The phone group only where there is a phone link (Flux answered) or Buds; network
  // and system always (Omarchy's network widget, our own CPU/RAM reading).
  readonly property var shownGroups: groups.filter(function(g) {
    return g.id !== "phone" || !!root.phone || root.embedIds.indexOf("io.github.nerdislb.buds-control") !== -1
  })

  // ---------------------------------------------------------------- embedded natives
  property var mounted: ({})    // id -> item
  // the theme material for their own (Omarchy) popups – and for
  // those of Omarchy's widgets that stay in its bar (audio, power, …): a
  // few passes after loading, as the bar's slots load one by one
  Root.NativeMaterial { id: nativeMaterial }
  function nativeReport() { return nativeMaterial.report(root) }
  // Quick passes while the bar starts, then a slow watch for good: Omarchy can
  // create its widgets later than our module (after the 04.10. bar startup
  // change its popups stayed undressed – no bloom on the volume popup) or
  // recreate them after a reload or settings change. A pass walks the bar's
  // slots only and skips panels that already carry a MaterialCard.
  Timer {
    id: dressTimer
    property int pass: 0
    interval: pass < 4 ? 1200 : 5000
    repeat: true
    running: true
    onTriggered: { nativeMaterial.forget(); nativeMaterial.dressBar(root); pass++ }
  }
  // The bar forwards clicks to every registered click target by geometry,
  // whatever its container's visibility, so the mounts live far above the
  // bar (no overlap with our cells). Only their x matters: the native popups
  // anchor horizontally to it (y is always "under the bar"), so it is moved
  // under the clicked cell before a popup opens.
  property real mountX: 0
  Item {
    id: mounts
    x: root.mountX
    y: -10000
    width: 0; height: root.barSize
    clip: true
    Repeater {
      model: root.stableMountIds
      Loader {
        id: mount
        required property string modelData
        width: root.barSize; height: root.barSize
        property MemberBar memberApi: MemberBar { host: root; memberId: mount.modelData }
        Component.onCompleted: setSource(root.filePath(root.catalogue[modelData].file), {
          bar: memberApi, moduleName: modelData, settings: root.embeds[modelData] || ({})
        })
        Binding {
          when: mount.item !== null && mount.item.settings !== undefined
          target: mount.item; property: "settings"
          value: root.embeds[mount.modelData] || ({})
          restoreMode: Binding.RestoreNone
        }
        onLoaded: {
          var m = Object.assign({}, root.mounted)
          m[modelData] = item
          root.mounted = m
          // Omarchy's own popup of this widget takes the theme material too
          var it = item
          Qt.callLater(function() { nativeMaterial.attach(it) })
        }
        Component.onDestruction: {
          var m = Object.assign({}, root.mounted)
          delete m[modelData]
          root.mounted = m
          nativeMaterial.forget()
        }
      }
    }
  }

  function openMember(id) {
    var a = popupAnchor || root
    mountX = a === root ? 0 : a.x + a.width / 2 - barSize / 2
    closePopup()
    var c = catalogue[id]
    if (!c) return
    if (c.command) { if (bar) bar.run(c.command); return }
    var it = mounted[id]
    if (!it) return
    // Click path first (anchored to the widget's own button).
    Qt.callLater(function() {
      if (typeof it.togglePanel === "function") it.togglePanel()
      else if (typeof it.toggle === "function") it.toggle()
      else if (typeof it.open === "function") it.open()
    })
  }

  // ---------------------------------------------------------------- live state
  property bool wifiUp: true
  property string wifiName: ""
  property bool vpnUp: false
  property string vpnName: ""
  property bool tailscaleUp: false
  property real cpu: 0
  property real mem: 0
  property var phone: null
  readonly property var btConnected: {
    var d = Bluetooth.devices ? Bluetooth.devices.values : []
    return d.filter(function(x) { return x && x.connected })
  }
  readonly property bool btOn: !!(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled)

  Process {
    id: nm
    command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active"]
    stdout: StdioCollector {
      onStreamFinished: {
        var wifi = "", vpn = ""
        String(text).split("\n").forEach(function(l) {
          var p = l.split(":")
          if (p.length < 2) return
          if ((p[1] === "802-11-wireless" || p[1] === "802-3-ethernet") && !wifi) wifi = p[0]
          if ((p[1] === "vpn" || p[1] === "wireguard") && !vpn) vpn = p[0]
        })
        root.wifiUp = wifi !== ""; root.wifiName = wifi
        root.vpnUp = vpn !== ""; root.vpnName = vpn
      }
    }
  }
  Process {
    id: ts
    command: ["tailscale", "status", "--json"]
    stdout: StdioCollector { onStreamFinished: { try { root.tailscaleUp = JSON.parse(text).BackendState === "Running" } catch (e) { root.tailscaleUp = false } } }
  }
  Process {
    id: flux
    command: ["flux-cli", "status", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var d = JSON.parse(text), list = d.devices || []
          var p = null
          for (var i = 0; i < list.length; i++) if (list[i].paired) { p = list[i]; break }
          root.phone = p ? { name: String(p.name || "Pixel"), online: !!p.online,
                             charge: p.battery ? Number(p.battery.charge) : -1, charging: !!(p.battery && p.battery.charging) } : null
        } catch (e) {}
      }
    }
  }
  property var lastCpu: null
  FileView {
    id: stat
    path: "/proc/stat"
    onLoaded: {
      var f = String(text()).split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
      var idle = f[3] + (f[4] || 0), total = f.reduce(function(a, b) { return a + b }, 0)
      if (root.lastCpu) {
        var dt = total - root.lastCpu.total, di = idle - root.lastCpu.idle
        root.cpu = dt > 0 ? Math.max(0, Math.min(1, 1 - di / dt)) : root.cpu
      }
      root.lastCpu = { total: total, idle: idle }
    }
  }
  FileView {
    id: meminfo
    path: "/proc/meminfo"
    onLoaded: {
      var t = String(text()), tot = /MemTotal:\s+(\d+)/.exec(t), av = /MemAvailable:\s+(\d+)/.exec(t)
      if (tot && av) root.mem = 1 - Number(av[1]) / Number(tot[1])
    }
  }
  Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { stat.reload(); meminfo.reload() } }
  Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!nm.running) nm.running = true }
  Timer { interval: 20000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { if (!ts.running) ts.running = true; if (!flux.running) flux.running = true } }

  function memberState(id) {
    if (id === "omarchy.network") return wifiUp ? "connected · " + wifiName : "disconnected"
    if (id === "io.github.iamfitsum.omarchy-proton-vpn") return vpnUp ? "active · " + vpnName : "off"
    if (id === "omarchy.tailscale") return tailscaleUp ? "online" : "off"
    if (id === "omarchy.bluetooth") return !btOn ? "off" : btConnected.length ? btConnected.map(function(d) { return d.name }).join(", ") : "on · nothing connected"
    if (id === "flux") return phone ? (phone.online ? "online" : "offline") + (phone.charge >= 0 ? " · " + phone.charge + " %" + (phone.charging ? " charging" : "") : "") : "not paired"
    if (id === "bitr0t.system-monitor") return "CPU " + Math.round(cpu * 100) + " % · RAM " + Math.round(mem * 100) + " %"
    return ""
  }
  function memberAlert(id) {
    if (id === "omarchy.network") return !wifiUp
    if (id === "bitr0t.system-monitor") return sysHot
    return false
  }
  // The system's warning: CPU near its limit or memory nearly full.
  readonly property bool sysHot: cpu > 0.85 || mem > 0.9
  // The chip's fill (system group face): CPU load in 6 rows; any load above 2 % shows at least one
  // row, so a quiet machine does not read as switched off.
  function chipLevel(load) {
    var l = Math.min(1, Math.max(0, Number(load) || 0))
    return l > 0.02 ? Math.max(1, Math.ceil(l * 6 - 1e-4)) : 0
  }

  // Deviations: what is worth showing right now.
  readonly property var deviations: {
    var out = []
    if (!wifiUp) out.push({ glyph: "\u{f05aa}", color: Commons.Color.urgent, member: "omarchy.network" })
    if (vpnUp) out.push({ glyph: "\u{f099d}", color: Commons.Color.accent, member: "io.github.iamfitsum.omarchy-proton-vpn" })
    if (!tailscaleUp) out.push({ glyph: "\u{f0570}", color: Util.alpha(fg, 0.5), member: "omarchy.tailscale" })
    if (btConnected.length) out.push({ glyph: "\u{f02cb}", color: fg, member: "omarchy.bluetooth" })
    if (phone && phone.online && phone.charge >= 0 && phone.charge <= 20 && !phone.charging) out.push({ glyph: "\u{f011c}", color: Commons.Color.urgent, member: "flux" })
    if (sysHot) out.push({ chip: true, color: Commons.Color.urgent, member: "bitr0t.system-monitor" })
    return out
  }

  // ---------------------------------------------------------------- bar row
  implicitHeight: barSize
  implicitWidth: row.implicitWidth + Style.space(4)

  Row {
    id: row
    height: root.barSize
    spacing: 0

    // groups
    Repeater {
      model: root.variant === "groups" ? root.shownGroups : []
      Cell {
        id: groupCell
        required property var modelData
        active: root.popupGroup === modelData.id && root.popupOpen
        onClicked: root.openGroup(modelData.id, groupCell)
        onRightClicked: { root.popupAnchor = groupCell; root.openMember(modelData.members[0]) }
        width: modelData.id === "phone" ? Style.space(58) : root.barSize + Style.space(2)
        GroupFace { anchors.fill: parent; group: modelData.id }
      }
    }

    // deviations
    Repeater {
      model: root.variant === "deviations" ? root.deviations : []
      Cell {
        id: devCell
        required property var modelData
        onClicked: { root.popupAnchor = devCell; root.openMember(modelData.member) }
        width: root.barSize
        Glyph { visible: !modelData.chip; anchors.centerIn: parent; text: modelData.glyph || ""; color: modelData.color }
        ChipFace { visible: !!modelData.chip; anchors.centerIn: parent; level: root.cpu }
      }
    }

    // "more": every embedded widget (deviations mode)
    Cell {
      id: moreCell
      visible: root.variant === "deviations"
      active: root.popupGroup === "all" && root.popupOpen
      width: root.barSize + Style.space(2)
      onClicked: root.openGroup("all", moreCell)
      Glyph { anchors.centerIn: parent; text: "\u{f01d8}"; color: Util.alpha(root.fg, 0.7) }
    }
  }

  component Cell: WidgetButton {
    id: cell
    bar: root.bar
    hasVisualContent: true
    labelVisible: false
    useActiveColor: false
    onPressed: function(button) { if (button === Qt.RightButton) rightClicked(); else clicked() }
    signal clicked()
    signal rightClicked()
    height: root.barSize
    Rectangle {
      anchors.fill: parent; anchors.topMargin: Style.space(3); anchors.bottomMargin: Style.space(3)
      radius: Math.min(Style.cornerRadius, 3)
      color: cell.active ? Style.selectedFillFor(root.fg, Commons.Color.accent, Commons.Color.urgent)
        : hover.hovered ? Style.hoverFillFor(root.fg, Commons.Color.accent, Commons.Color.urgent) : "transparent"
    }
    HoverHandler { id: hover }
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: function(m) { if (m.button === Qt.RightButton) cell.rightClicked(); else cell.clicked() }
    }
  }

  component Glyph: Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
    font.family: Style.font.family
    font.pixelSize: Style.font.icon + 2
    color: root.fg
  }

  component GroupFace: Item {
    property string group: ""
    Glyph {
      visible: parent.group === "net"
      anchors.centerIn: parent; anchors.verticalCenterOffset: -Style.space(2)
      text: root.wifiUp ? "\u{f0928}" : "\u{f05aa}"
      color: root.wifiUp ? root.fg : Commons.Color.urgent
    }
    Row {
      visible: parent.group === "net"
      anchors.horizontalCenter: parent.horizontalCenter
      y: root.barSize - Style.space(7)
      spacing: Style.space(2)
      Rectangle { width: Style.space(3); height: width; color: root.vpnUp ? Commons.Color.accent : Util.alpha(root.fg, 0.25) }
      Rectangle { width: Style.space(3); height: width; color: root.tailscaleUp ? (Commons.Color.popups.border || root.fg) : Util.alpha(root.fg, 0.25) }
      Rectangle { width: Style.space(3); height: width; color: root.btConnected.length ? root.fg : Util.alpha(root.fg, 0.25) }
    }
    Row {
      visible: parent.group === "phone"
      anchors.centerIn: parent
      spacing: Style.space(3)
      Glyph { text: "\u{f011c}"; color: root.phone && root.phone.online ? root.fg : Util.alpha(root.fg, 0.45) }
      Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
        anchors.verticalCenter: parent.verticalCenter
        text: root.phone && root.phone.charge >= 0 ? root.phone.charge + "%" : "–"
        font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
        color: root.phone && root.phone.charge >= 0 && root.phone.charge <= 20 && !root.phone.charging ? Commons.Color.urgent : Util.alpha(root.fg, 0.75)
      }
    }
    ChipFace {
      visible: parent.group === "system"
      anchors.centerIn: parent
      level: root.cpu
    }
  }

  // The system group's face (design round 04.10., recommendation 6): a chip drawn as an outline on
  // whole pixels – 12 × 12 with the phone glyph's 2 px stroke, three pins per side – that fills from
  // below like the battery beside it (CPU, chipLevel). Under the warning (sysHot) only the fill takes
  // the alarm tone; the outline stays the bar's ink, so it never becomes a red block. Scales by whole
  // pixels with the icon size (16 px at the 18 px glyph).
  component ChipFace: Item {
    id: chip
    property real level: 0
    readonly property int u: Math.max(1, Math.round((Style.font.icon + 2) / 18))
    readonly property color ink: root.fg
    readonly property color fillInk: root.sysHot ? Commons.Color.urgent : root.fg
    width: 16 * u; height: 16 * u
    Repeater {
      model: 12
      Rectangle {
        required property int index
        readonly property int side: Math.floor(index / 3)
        readonly property int k: index % 3
        color: chip.ink
        antialiasing: false
        width: (side < 2 ? 2 : 1) * chip.u; height: (side < 2 ? 1 : 2) * chip.u
        x: (side === 0 ? 0 : side === 1 ? 14 : 4 + k * 3) * chip.u
        y: (side === 2 ? 0 : side === 3 ? 14 : 4 + k * 3) * chip.u
      }
    }
    Rectangle {
      x: 2 * chip.u; y: 2 * chip.u; width: 12 * chip.u; height: 12 * chip.u
      color: "transparent"; border.width: 2 * chip.u; border.color: chip.ink; radius: chip.u
      Rectangle {
        readonly property int rows: root.chipLevel(chip.level)
        x: 3 * chip.u; width: 6 * chip.u
        height: rows * chip.u; y: (9 - rows) * chip.u
        visible: rows > 0
        color: chip.fillInk
        antialiasing: false
      }
    }
  }

  // ---------------------------------------------------------------- popup (group list)
  property bool popupOpen: false
  property string popupGroup: ""
  property Item popupAnchor: root
  readonly property bool opened: popupOpen
  property bool popoutSwitchClosing: false
  function open() { popupOpen = true }
  function close() { popupOpen = false }
  function closePopup() { popupOpen = false }
  function closeForPopoutSwitch() { popoutSwitchClosing = true; popupOpen = false; Qt.callLater(function() { root.popoutSwitchClosing = false }) }
  function openGroup(id, anchor) {
    if (popupOpen && popupGroup === id) { popupOpen = false; return }
    popupGroup = id
    popupAnchor = anchor || root
    popupOpen = true
  }
  readonly property var popupMembers: {
    if (popupGroup === "all") return embedIds
    for (var i = 0; i < groups.length; i++) if (groups[i].id === popupGroup) return groups[i].members.filter(function(m) { return root.embedIds.indexOf(m) !== -1 })
    return []
  }
  readonly property string popupTitle: popupGroup === "all" ? "All widgets" : (function() { for (var i = 0; i < groups.length; i++) if (groups[i].id === popupGroup) return groups[i].name; return "" })()

  function stateJson() {
    return JSON.stringify({variant: variant, mounted: Object.keys(mounted), wifi: wifiName,
      vpn: vpnUp, tailscale: tailscaleUp, phone: phone, cpu: cpu, mem: mem,
      open: popupOpen, group: popupGroup, monitor: root.QsWindow.window ? root.QsWindow.window.screen.name : ""})
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.popupAnchor
    owner: root
    bar: root.bar
    open: root.popupOpen
    padding: Style.spacing.popupPadding
    focusTarget: popupKeys
    contentWidth: Style.space(360)
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    // Theme material: the popup rolls out of the bar as a card.
    Root.BarMaterialCard { panel: popup; material: Bridge.ModuleBus.material }

    Item {
      id: popupKeys
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: function(e) { root.closePopup(); e.accepted = true }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(4)

        Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
          text: root.popupTitle
          font.family: Style.font.family; font.bold: true; font.pixelSize: Style.font.title
          color: Commons.Color.popups.text
          bottomPadding: Style.space(4)
        }

        Repeater {
          model: root.popupMembers
          Rectangle {
            required property string modelData
            width: content.width; height: Style.space(40)
            radius: Math.min(Style.cornerRadius, 3)
            color: rowHover.hovered ? Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent, Commons.Color.urgent) : "transparent"
            Row {
              anchors.fill: parent; anchors.leftMargin: Style.space(8)
              spacing: Style.space(10)
              Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; width: Style.space(20); text: root.catalogue[modelData].glyph; font.family: Style.font.family; font.pixelSize: Style.font.icon + 2; color: root.memberAlert(modelData) ? Commons.Color.urgent : Commons.Color.popups.text }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; text: root.catalogue[modelData].name; font.family: Style.font.family; font.pixelSize: Style.font.body; color: Commons.Color.popups.text }
                Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; visible: text !== ""; text: root.memberState(modelData); font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.memberAlert(modelData) ? Commons.Color.urgent : Util.alpha(Commons.Color.popups.text, 0.6) }
              }
            }
            Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; anchors.right: parent.right; anchors.rightMargin: Style.space(10); anchors.verticalCenter: parent.verticalCenter; text: "›"; font.family: Style.font.family; font.pixelSize: Style.font.title; color: Util.alpha(Commons.Color.popups.text, 0.5) }
            HoverHandler { id: rowHover }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openMember(parent.modelData) }
          }
        }
      }
    }
  }
}
