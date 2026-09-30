import QtQuick
import "../bridge" as Bridge
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui

// The right side, compact. Custom QML module of the Amiga Bar:
//   { "id": "amiga.status", "source": ".../modules/Status.qml",
//     "variant": "groups" | "deviations" | "drawer", "embeds": { id: settings } }
//
// The widgets it replaces are mounted here, invisibly (`embeds`), so their
// own native popups (Wi-Fi list, Bluetooth devices, VPN map …) still open —
// from our group rows or the drawer. Flux and the mail/WhatsApp widgets need
// their own services and are not embedded; Flux is read from its socket CLI
// and opened as its own window.
Item {
  id: root
  Component.onCompleted: { stableMountIds = mountIds; Bridge.ModuleBus.register("status", root) }
  Component.onDestruction: Bridge.ModuleBus.unregister("status", root)

  property var bar: null
  property string moduleName: "amiga.status"
  property var settings: ({})
  function setting(key, fallback) { var v = settings ? settings[key] : undefined; return v === undefined || v === null ? fallback : v }

  readonly property string variant: String(setting("variant", "groups"))
  readonly property var embeds: setting("embeds", {})
  readonly property int barSize: bar && bar.barSize ? bar.barSize : Style.bar.sizeHorizontal
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : Color.bar.text
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
    "flux": { name: "Flux · Pixel", glyph: "\u{f011c}", command: "omarchy-shell shell toggle flux" },
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
    { id: "phone", name: "Pixel", members: ["flux", "io.github.nerdislb.buds-control"] },
    { id: "system", name: "System", members: ["bitr0t.system-monitor", "nerdibeard.monitor", "nerdibeard.googledrive", "com.omastorm.radar", "community.plugin-manager"] }
  ]

  // ---------------------------------------------------------------- embedded natives
  property var mounted: ({})    // id -> item
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
        }
        Component.onDestruction: {
          var m = Object.assign({}, root.mounted)
          delete m[modelData]
          root.mounted = m
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
    if (id === "bitr0t.system-monitor") return cpu > 0.85
    return false
  }

  // Deviations: what is worth showing right now.
  readonly property var deviations: {
    var out = []
    if (!wifiUp) out.push({ glyph: "\u{f05aa}", color: Color.urgent, member: "omarchy.network" })
    if (vpnUp) out.push({ glyph: "\u{f099d}", color: Color.accent, member: "io.github.iamfitsum.omarchy-proton-vpn" })
    if (!tailscaleUp) out.push({ glyph: "\u{f0570}", color: Util.alpha(fg, 0.5), member: "omarchy.tailscale" })
    if (btConnected.length) out.push({ glyph: "\u{f02cb}", color: fg, member: "omarchy.bluetooth" })
    if (phone && phone.online && phone.charge >= 0 && phone.charge <= 20 && !phone.charging) out.push({ glyph: "\u{f011c}", color: Color.urgent, member: "flux" })
    if (cpu > 0.85) out.push({ glyph: "\u{f061a}", color: Color.urgent, member: "bitr0t.system-monitor" })
    return out
  }

  // ---------------------------------------------------------------- A500 hardware strip state
  readonly property bool hardware: variant === "hardware"
  readonly property bool onBattery: UPower.onBattery
  readonly property real batteryLevel: UPower.displayDevice && UPower.displayDevice.isPresent ? Math.max(0, Math.min(1, UPower.displayDevice.percentage)) : 1
  property bool driveActive: false
  property var lastSectors: -1
  FileView {
    id: diskstats
    path: "/proc/diskstats"
    onLoaded: {
      var total = 0
      String(text()).split("\n").forEach(function(l) {
        var f = l.trim().split(/\s+/)
        if (f.length > 10 && /^(nvme\d+n\d+|sd[a-z]|mmcblk\d+)$/.test(f[2])) total += Number(f[5]) + Number(f[9])
      })
      root.driveActive = root.lastSectors >= 0 && total > root.lastSectors
      root.lastSectors = total
    }
  }
  Timer { interval: 250; running: root.hardware; repeat: true; onTriggered: diskstats.reload() }
  // DF0: a phone plugged in over USB (product name from sysfs).
  property string usbPhone: ""
  Process {
    id: usb
    command: ["sh", "-c", "cat /sys/bus/usb/devices/*/product 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: {
        var hit = String(text).split("\n").filter(function(l) { return /pixel|galaxy|android|phone/i.test(l) })
        root.usbPhone = hit.length ? hit[0].trim() : ""
      }
    }
  }
  Timer { interval: 5000; running: root.hardware; repeat: true; triggeredOnStart: true; onTriggered: if (!usb.running) usb.running = true }

  // ---------------------------------------------------------------- bar row
  implicitHeight: barSize
  implicitWidth: row.implicitWidth + Style.space(4)

  Row {
    id: row
    height: root.barSize
    spacing: 0

    // groups
    Repeater {
      model: root.variant === "groups" ? root.groups : []
      Cell {
        id: groupCell
        required property var modelData
        active: root.popupGroup === modelData.id && root.popupOpen
        onClicked: root.openGroup(modelData.id, groupCell)
        onRightClicked: { root.popupAnchor = groupCell; root.openMember(modelData.members[0]) }
        width: modelData.id === "system" ? Style.space(58) : modelData.id === "phone" ? Style.space(58) : root.barSize + Style.space(2)
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
        Glyph { anchors.centerIn: parent; text: modelData.glyph; color: modelData.color }
      }
    }

    // A500 case strip: VU for CPU/RAM, POWER and DRIVE LEDs, DF0: slot.
    Item {
      id: caseStrip
      visible: root.hardware
      width: visible ? caseRow.implicitWidth + Style.space(16) : 0
      height: root.barSize
      Rectangle {
        anchors.fill: parent; anchors.topMargin: Style.space(3); anchors.bottomMargin: Style.space(3)
        color: Qt.lighter(Color.bar.background, 1.35)
        Rectangle { width: parent.width; height: 1; color: Util.alpha(root.fg, 0.25) }
        Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: Qt.darker(Color.bar.background, 1.6) }
      }
      Row {
        id: caseRow
        x: Style.space(8)
        height: parent.height
        spacing: Style.space(10)
        Repeater {
          model: [["CPU", root.cpu], ["RAM", root.mem]]
          Row {
            required property var modelData
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(3)
            Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: modelData[0]; font.family: Bridge.ModuleBus.family; font.bold: true; font.pixelSize: Bridge.ModuleBus.px(Style.font.caption - 1); color: Util.alpha(root.fg, 0.6) }
            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 1
              Repeater {
                model: 8
                Rectangle {
                  required property int index
                  readonly property int seg: 7 - index
                  width: Style.space(7); height: Math.max(1, Math.round(root.barSize * 0.055))
                  color: parent.parent.modelData[1] * 8 > seg + 0.01 ? (seg >= 7 ? Color.urgent : seg >= 5 ? Color.accent : (Color.popups.border || root.fg)) : Util.alpha(root.fg, 0.12)
                }
              }
            }
          }
        }
        Led {
          caption: "POWER"
          on: true
          tone: !root.onBattery ? "#3ee05a" : root.batteryLevel <= 0.2 ? Color.urgent : "#ffae2b"
          onClicked: { root.popupAnchor = caseStrip; root.openMember("omarchy.power") }
        }
        Led { caption: "DRIVE"; on: root.driveActive; tone: "#ffb000"; onClicked: root.openGroup("all", caseStrip) }
        WidgetButton {
          id: df0
          bar: root.bar
          hasVisualContent: true
          labelVisible: false
          useActiveColor: false
          onPressed: function(button) { root.openMember("flux") }
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(128); height: root.barSize
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: Math.round(root.barSize * 0.56)
            color: Qt.darker(Color.bar.background, 1.3)
            border.width: 1; border.color: Util.alpha(root.fg, 0.15)
            Text { id: df0Label; renderType: Text.NativeRendering; textFormat: Text.PlainText; x: Style.space(6); anchors.verticalCenter: parent.verticalCenter; text: "DF0:"; font.family: Bridge.ModuleBus.family; font.bold: true; font.pixelSize: Bridge.ModuleBus.px(Style.font.caption); color: Util.alpha(root.fg, 0.6) }
            Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
              x: df0Label.x + df0Label.implicitWidth + Style.space(6); width: parent.width - x - Style.space(4); anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight
              text: root.usbPhone || "—"
              font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.caption); color: root.usbPhone ? root.fg : Util.alpha(root.fg, 0.4)
            }
          }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openMember("flux") }
        }
      }
    }

    // drawer (also the "more" entry of the deviations mode)
    Cell {
      id: drawerCell
      visible: root.variant === "drawer" || root.variant === "deviations" || root.hardware
      active: root.popupGroup === "all" && root.popupOpen
      width: root.barSize + Style.space(2)
      onClicked: root.openGroup("all", drawerCell)
      Drawer { anchors.centerIn: parent; open: parent.active; visible: root.variant === "drawer" || root.hardware }
      Glyph { anchors.centerIn: parent; visible: root.variant === "deviations"; text: "\u{f01d8}"; color: Util.alpha(root.fg, 0.7) }
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
      color: cell.active ? Style.selectedFillFor(root.fg, Color.accent, Color.urgent)
        : hover.hovered ? Style.hoverFillFor(root.fg, Color.accent, Color.urgent) : "transparent"
    }
    HoverHandler { id: hover }
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: function(m) { if (m.button === Qt.RightButton) cell.rightClicked(); else cell.clicked() }
    }
  }

  // LEDs and the DF0: slot are registered bar click targets like the cells,
  // so clicks on the bar edge reach them too.
  component Led: WidgetButton {
    id: led
    property string caption: ""
    property bool on: false
    property color tone: "#3ee05a"
    signal clicked()
    readonly property bool pixel: Bridge.ModuleBus.pixelAll
    bar: root.bar
    hasVisualContent: true
    labelVisible: false
    useActiveColor: false
    onPressed: function(button) { led.clicked() }
    // Theme font: caption above the LED. Pixel font: LED beside its caption,
    // as on the A500 case (a 16 px caption leaves no room above).
    // Both layouts derive from the caption only (no width <-> x loop).
    readonly property real themeWidth: Math.max(Style.space(34), ledText.implicitWidth + Style.space(4))
    readonly property real pixelTextX: Style.space(2) + 12 + 5
    width: pixel ? pixelTextX + ledText.implicitWidth + Style.space(2) : themeWidth
    height: root.barSize
    Text { id: ledText; renderType: Text.NativeRendering; textFormat: Text.PlainText
      x: led.pixel ? led.pixelTextX : Math.round((led.themeWidth - implicitWidth) / 2)
      y: led.pixel ? Math.round((root.barSize - 16) / 2) : Style.space(4)
      text: led.caption; font.family: Bridge.ModuleBus.family; font.bold: true; font.pixelSize: Bridge.ModuleBus.px(Math.max(7, Style.font.caption - 3)); color: Util.alpha(root.fg, 0.6) }
    Rectangle {
      id: ledBar
      x: led.pixel ? Style.space(2) : Math.round((led.themeWidth - width) / 2)
      y: led.pixel ? Math.round((root.barSize - height) / 2) : root.barSize - Style.space(10)
      width: led.pixel ? 12 : Style.space(28); height: led.pixel ? 6 : Math.max(3, Style.space(5))
      color: led.on ? led.tone : Util.alpha(led.tone, 0.18)
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: led.clicked() }
  }

  component Glyph: Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
    font.family: Bridge.ModuleBus.family
    font.pixelSize: Bridge.ModuleBus.px(Style.font.icon + 2)
    color: root.fg
  }

  component GroupFace: Item {
    property string group: ""
    Glyph {
      visible: parent.group === "net"
      anchors.centerIn: parent; anchors.verticalCenterOffset: -Style.space(2)
      text: root.wifiUp ? "\u{f0928}" : "\u{f05aa}"
      color: root.wifiUp ? root.fg : Color.urgent
    }
    Row {
      visible: parent.group === "net"
      anchors.horizontalCenter: parent.horizontalCenter
      y: root.barSize - Style.space(7)
      spacing: Style.space(2)
      Rectangle { width: Style.space(3); height: width; color: root.vpnUp ? Color.accent : Util.alpha(root.fg, 0.25) }
      Rectangle { width: Style.space(3); height: width; color: root.tailscaleUp ? (Color.popups.border || root.fg) : Util.alpha(root.fg, 0.25) }
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
        font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.bodySmall)
        color: root.phone && root.phone.charge >= 0 && root.phone.charge <= 20 && !root.phone.charging ? Color.urgent : Util.alpha(root.fg, 0.75)
      }
    }
    Row {
      visible: parent.group === "system"
      anchors.centerIn: parent
      spacing: Style.space(4)
      Glyph { text: "\u{f061a}"; color: root.cpu > 0.85 ? Color.urgent : root.fg }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(3)
        Rectangle { width: Style.space(26); height: Math.max(2, Style.space(3)); color: Util.alpha(root.fg, 0.15)
          Rectangle { width: parent.width * root.cpu; height: parent.height; color: root.cpu > 0.85 ? Color.urgent : Color.accent } }
        Rectangle { width: Style.space(26); height: Math.max(2, Style.space(3)); color: Util.alpha(root.fg, 0.15)
          Rectangle { width: parent.width * root.mem; height: parent.height; color: Util.alpha(root.fg, 0.8) } }
      }
    }
  }

  // Workbench 1.3 drawer icon.
  component Drawer: Item {
    property bool open: false
    width: Math.round(root.barSize * 0.62); height: Math.round(width * 0.82)
    Rectangle { anchors.fill: parent; color: "#0055aa"; border.width: 1; border.color: "#ffffff" }
    Rectangle { x: 2; y: parent.open ? parent.height * 0.52 : parent.height * 0.4; width: parent.width - 4; height: 1; color: "#ffffff" }
    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: parent.open ? parent.height * 0.64 : parent.height * 0.56; width: parent.width * 0.26; height: 2; color: "#ff8800" }
  }

  // ---------------------------------------------------------------- popup (group list / drawer window)
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
  readonly property string popupTitle: popupGroup === "all" ? "System" : (function() { for (var i = 0; i < groups.length; i++) if (groups[i].id === popupGroup) return groups[i].name; return "" })()
  readonly property bool workbench: popupGroup === "all" && (variant === "drawer" || variant === "hardware")

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
    padding: root.workbench ? 0 : Style.spacing.popupPadding
    focusTarget: popupKeys
    contentWidth: root.workbench ? Style.space(470) : Style.space(360)
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    Item {
      id: popupKeys
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: function(e) { root.closePopup(); e.accepted = true }

      Column {
        id: content
        width: parent.width
        spacing: root.workbench ? 0 : Style.space(4)

        // Workbench title bar (drawer mode)
        Rectangle {
          visible: root.workbench
          width: parent.width; height: Style.space(24)
          color: Color.accent
          Row {
            anchors.fill: parent; anchors.leftMargin: Style.space(8)
            spacing: Style.space(8)
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Style.space(12); height: width; color: "transparent"; border.width: 1; border.color: Color.popups.background
              Rectangle { anchors.centerIn: parent; width: 4; height: 4; color: Color.popups.background } }
            Text { textFormat: Text.PlainText;
              anchors.verticalCenter: parent.verticalCenter
              text: root.popupTitle
              font.family: Bridge.ModuleBus.momentFamily
              font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.title)
              font.bold: !Bridge.ModuleBus.pixelMoments
              renderType: Text.NativeRendering
              color: Color.popups.background
            }
          }
          // drag stripes
          Column {
            anchors.right: parent.right; anchors.rightMargin: Style.space(8); anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Repeater { model: 4; Rectangle { width: Style.space(110); height: 1; color: Util.alpha(Color.popups.background, 0.6) } }
          }
        }

        Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
          visible: !root.workbench
          text: root.popupTitle
          font.family: Bridge.ModuleBus.family; font.bold: true; font.pixelSize: Bridge.ModuleBus.px(Style.font.title)
          color: Color.popups.text
          bottomPadding: Style.space(4)
        }

        // rows (groups) or icon grid (drawer)
        Grid {
          visible: root.workbench
          width: parent.width
          columns: 4
          padding: Style.space(12)
          rowSpacing: Style.space(10)
          Repeater {
            model: root.workbench ? root.popupMembers : []
            Item {
              required property string modelData
              width: (content.width - Style.space(24)) / 4; height: Style.space(64)
              Rectangle { anchors.fill: parent; anchors.margins: 2; color: iconHover.hovered ? Util.alpha(Color.popups.text, 0.08) : "transparent" }
              Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; y: Style.space(4); text: root.catalogue[modelData].glyph; font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.space(28)); color: root.memberAlert(modelData) ? Color.urgent : Color.popups.text }
              Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; y: Style.space(40); width: parent.width - 4; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: root.catalogue[modelData].name; font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.caption); color: Color.popups.text }
              HoverHandler { id: iconHover }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openMember(parent.modelData) }
            }
          }
        }

        Repeater {
          model: root.workbench ? [] : root.popupMembers
          Rectangle {
            required property string modelData
            width: content.width; height: Style.space(40)
            radius: Math.min(Style.cornerRadius, 3)
            color: rowHover.hovered ? Style.hoverFillFor(Color.popups.text, Color.accent, Color.urgent) : "transparent"
            Row {
              anchors.fill: parent; anchors.leftMargin: Style.space(8)
              spacing: Style.space(10)
              Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; width: Style.space(20); text: root.catalogue[modelData].glyph; font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.icon + 2); color: root.memberAlert(modelData) ? Color.urgent : Color.popups.text }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; text: root.catalogue[modelData].name; font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.body); color: Color.popups.text }
                Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; visible: text !== ""; text: root.memberState(modelData); font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.caption); color: root.memberAlert(modelData) ? Color.urgent : Util.alpha(Color.popups.text, 0.6) }
              }
            }
            Text { renderType: Text.NativeRendering; textFormat: Text.PlainText; anchors.right: parent.right; anchors.rightMargin: Style.space(10); anchors.verticalCenter: parent.verticalCenter; text: "›"; font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.title); color: Util.alpha(Color.popups.text, 0.5) }
            HoverHandler { id: rowHover }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openMember(parent.modelData) }
          }
        }

        Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
          visible: root.workbench
          leftPadding: Style.space(12); bottomPadding: Style.space(10)
          text: "Click opens the widget's own Omarchy popup"
          font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.caption)
          color: Util.alpha(Color.popups.text, 0.5)
        }
      }
    }
  }
}
