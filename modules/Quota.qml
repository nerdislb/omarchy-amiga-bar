import QtQuick
import "../bridge" as Bridge
import ".." as Root
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// AI quotas, compact. Custom QML module of the Amiga Bar:
//   { "id": "amiga.quota", "source": ".../modules/Quota.qml",
//     "variant": "gauge" | "vu" | "rings" | "ondemand" }
// Data: Omarchy's agent usage files (~/.local/state/omarchy/agents/usage)
// plus the DeepSeek balance; which limits are shown follows the existing
// AI-usage selection (~/.config/omarchy/ai-usage-deepseek.json "tracked").
// Left click: all limits with reset times; middle click: refresh now.
Item {
  id: root
  Component.onCompleted: Bridge.ModuleBus.register("quota", root)
  Component.onDestruction: Bridge.ModuleBus.unregister("quota", root)

  property var bar: null
  property string moduleName: "amiga.quota"
  property var settings: ({})
  function setting(key, fallback) { var v = settings ? settings[key] : undefined; return v === undefined || v === null ? fallback : v }

  readonly property string variant: String(setting("variant", "gauge"))
  readonly property int barSize: bar && bar.barSize ? bar.barSize : Style.bar.sizeHorizontal
  readonly property color fg: bar && bar.barForeground ? bar.barForeground : Color.bar.text
  readonly property string home: Quickshell.env("HOME")
  readonly property string usageDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/omarchy/agents/usage"

  // ---------------------------------------------------------------- theme tones
  property var pal: ({})
  FileView {
    path: Color.currentThemePath + "/colors.toml"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      var out = {}, re = /^\s*([A-Za-z0-9_]+)\s*=\s*"(#[0-9A-Fa-f]{6,8})"/gm, m
      var t = text()
      while ((m = re.exec(t)) !== null) out[m[1]] = m[2]
      root.pal = out
    }
  }
  function tone(p) {
    if (p >= 0.9) return Color.urgent
    if (p >= 0.75) return Color.accent
    if (p >= 0.5) return pal.yellow || Color.accent
    return pal.green || fg
  }

  // ---------------------------------------------------------------- data
  property var tracked: ["claude:session-5-hour", "codex:weekly-7-day", "deepseek:balance-usd", "antigravity:gemini-weekly"]
  FileView {
    path: root.home + "/.config/omarchy/ai-usage-deepseek.json"
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { var t = JSON.parse(text()).tracked; if (Array.isArray(t) && t.length) root.tracked = t } catch (e) {} }
  }

  property var providers: ({})   // id -> { name, limits: [...] }
  function setProvider(id, text) {
    var d
    try { d = JSON.parse(text) } catch (e) { return }
    var next = {}
    for (var k in providers) next[k] = providers[k]
    next[id] = { name: String(d.name || d.id || id), limits: Array.isArray(d.limits) ? d.limits : [] }
    providers = next
  }
  Instantiator {
    model: ["claude", "codex", "antigravity"]
    delegate: FileView {
      required property string modelData
      path: root.usageDir + "/" + modelData + ".json"
      printErrors: false
      watchChanges: true
      onFileChanged: reload()
      onLoaded: root.setProvider(modelData, text())
    }
  }
  FileView {
    path: root.home + "/.local/state/deepseek-usage/display.json"
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.setProvider("deepseek", text())
  }

  function slug(s) { return String(s || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") }
  readonly property var names: ({ claude: "Claude", codex: "Codex", deepseek: "DeepSeek", antigravity: "Gemini" })
  readonly property var letters: ({ claude: "C", codex: "X", deepseek: "D", antigravity: "G" })

  // A limit whose reset time has passed is back at 0 %, whatever the record
  // still says: records only change when a collector runs. Such a limit is
  // marked expired and asks the engine for fresh limits.
  property double now: Date.now()
  Timer { interval: 30000; running: true; repeat: true; onTriggered: root.now = Date.now() }

  // Tracked limits in order: { key, provider, name, label, percent (-1 = no quota), value, resetsAt, expired }
  readonly property var items: {
    var out = []
    for (var i = 0; i < tracked.length; i++) {
      var parts = String(tracked[i]).split(":")
      var p = providers[parts[0]]
      if (!p) continue
      for (var j = 0; j < p.limits.length; j++) {
        var l = p.limits[j]
        if (slug(l.label) !== parts[1]) continue
        var resets = Date.parse(String(l.resetsAt || ""))
        var expired = !l.noQuota && resets > 0 && resets <= now
        out.push({ key: tracked[i], provider: parts[0], name: names[parts[0]] || p.name, label: String(l.title || l.label || ""),
                   percent: l.noQuota ? -1 : expired ? 0 : Math.max(0, Number(l.percent) || 0), value: String(l.valueText || ""),
                   resetsAt: String(l.resetsAt || ""), expired: expired })
      }
    }
    return out
  }
  readonly property var quotaItems: items.filter(function(x) { return x.percent >= 0 })
  readonly property bool anyExpired: items.some(function(x) { return x.expired })
  onAnyExpiredChanged: if (anyExpired) Bridge.ModuleBus.requestUsageRefresh("limits")
  readonly property var tightest: {
    var best = null
    for (var i = 0; i < quotaItems.length; i++) if (!best || quotaItems[i].percent > best.percent) best = quotaItems[i]
    return best
  }
  readonly property var balance: { for (var i = 0; i < items.length; i++) if (items[i].percent < 0) return items[i]; return null }

  function shortLabel(l) {
    if (/session|5.hour/i.test(l)) return "5h"
    if (/week/i.test(l)) return "week"
    return l
  }
  function resetText(iso) {
    if (!iso) return ""
    var ms = Date.parse(iso) - Date.now()
    if (!(ms > 0)) return ""
    var m = Math.round(ms / 60000)
    if (m < 60) return m + " min"
    var h = Math.floor(m / 60)
    if (h < 48) return h + " h " + (m % 60) + " min"
    return Math.floor(h / 24) + " d " + (h % 24) + " h"
  }

  // ---------------------------------------------------------------- layout
  readonly property bool hidden: variant === "ondemand" && !(tightest && tightest.percent >= 0.75)
  visible: !hidden
  implicitHeight: barSize
  implicitWidth: hidden ? 0 : (loader.item ? loader.item.implicitWidth : 0) + Style.space(8)

  Loader {
    id: loader
    x: Style.space(4)
    height: root.barSize
    sourceComponent: root.variant === "vu" ? vuView : root.variant === "rings" ? ringsView
      : root.variant === "ondemand" ? chipView : root.variant === "title" ? titleView : gaugeView
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(m) {
      if (m.button === Qt.MiddleButton) { if (root.bar) root.bar.run("omarchy-agent-usage-update --force"); return }
      root.togglePopup()
    }
  }

  // Title line: one calm line like the Workbench screen title
  // ("Workbench release. 421,520 free memory"), Topaz if chosen.
  property real freeGiB: 0
  FileView {
    id: meminfo
    path: "/proc/meminfo"
    onLoaded: { var m = /MemAvailable:\s+(\d+)/.exec(String(text())); if (m) root.freeGiB = Number(m[1]) / 1048576 }
  }
  Timer { interval: 10000; running: root.variant === "title"; repeat: true; triggeredOnStart: true; onTriggered: meminfo.reload() }
  readonly property string titleText: "Workbench  " + freeGiB.toFixed(1) + "G free" + quotaItems.map(function(q) {
    return "  " + q.name + " " + Math.round(q.percent * 100) + "%" }).join("")
  Component {
    id: titleView
    Item {
      height: root.barSize
      // Hires Topaz (8 px per character) keeps the line clear of the centre.
      implicitWidth: line.implicitWidth
      Text {
        id: line
        anchors.verticalCenter: parent.verticalCenter
        text: root.titleText
        font.family: Bridge.ModuleBus.momentFamily
        font.pixelSize: Bridge.ModuleBus.momentPx(Style.font.body)
        renderType: Text.NativeRendering
        color: root.tightest && root.tightest.percent >= 0.9 ? root.tone(root.tightest.percent) : Util.alpha(root.fg, 0.8)
      }
    }
  }

  // Gauge: the tightest limit, coloured by level.
  Component {
    id: gaugeView
    Row {
      spacing: Style.space(5)
      height: root.barSize
      Text { renderType: Text.NativeRendering;
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{f04c5}"
        font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.icon + 2)
        color: root.tightest ? root.tone(root.tightest.percent) : root.fg
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)
        Row {
          spacing: Style.space(4)
          Text { renderType: Text.NativeRendering; text: root.tightest ? root.tightest.name : "AI"; font.family: Bridge.ModuleBus.family; font.bold: true; font.pixelSize: Bridge.ModuleBus.px(Style.font.caption); color: Util.alpha(root.fg, 0.65) }
          Text { renderType: Text.NativeRendering; text: root.tightest ? Math.round(root.tightest.percent * 100) + "%" : "–"; font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.bodySmall); color: root.fg }
        }
        Rectangle {
          width: Style.space(62); height: Math.max(2, Style.space(4))
          color: Util.alpha(root.fg, 0.15)
          Rectangle { width: parent.width * (root.tightest ? Math.min(1, root.tightest.percent) : 0); height: parent.height; color: root.tightest ? root.tone(root.tightest.percent) : root.fg }
        }
      }
    }
  }

  // Tracker VU: one channel per tracked quota, 8 segments.
  Component {
    id: vuView
    Row {
      spacing: Style.space(6)
      height: root.barSize
      Repeater {
        model: root.quotaItems
        Row {
          required property var modelData
          spacing: Style.space(2)
          anchors.verticalCenter: parent.verticalCenter
          Text { renderType: Text.NativeRendering; anchors.verticalCenter: parent.verticalCenter; text: root.letters[modelData.provider] || "?"; font.family: Bridge.ModuleBus.family; font.bold: true; font.pixelSize: Bridge.ModuleBus.px(Style.font.caption); color: Util.alpha(root.fg, 0.65) }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Repeater {
              model: 8
              Rectangle {
                required property int index
                readonly property int seg: 7 - index
                width: Style.space(7); height: Math.max(1, Math.round(root.barSize * 0.055))
                color: parent.parent.modelData.percent * 8 > seg + 0.001 || (seg === 0 && parent.parent.modelData.percent > 0)
                  ? (seg >= 7 ? Color.urgent : seg >= 5 ? (root.pal.yellow || Color.accent) : (root.pal.green || root.fg))
                  : Util.alpha(root.fg, 0.12)
              }
            }
          }
        }
      }
      Text { renderType: Text.NativeRendering;
        visible: !!root.balance
        anchors.verticalCenter: parent.verticalCenter
        text: root.balance ? root.balance.value.replace(/^USD\s*/, "$") : ""
        font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.caption); color: Util.alpha(root.fg, 0.75)
      }
    }
  }

  // Rings: one arc per tracked quota, provider initial inside.
  Component {
    id: ringsView
    Row {
      spacing: Style.space(5)
      height: root.barSize
      Repeater {
        model: root.quotaItems
        Canvas {
          id: ring
          required property var modelData
          anchors.verticalCenter: parent.verticalCenter
          width: Math.round(root.barSize * 0.66); height: width
          onPaint: {
            var c = getContext("2d"); c.reset()
            var r = width / 2 - 2
            c.lineWidth = Math.max(2, width * 0.13)
            c.strokeStyle = Util.alpha(root.fg, 0.15)
            c.beginPath(); c.arc(width / 2, height / 2, r, 0, Math.PI * 2); c.stroke()
            c.strokeStyle = root.tone(modelData.percent)
            c.beginPath(); c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.03, Math.min(1, modelData.percent))); c.stroke()
          }
          Connections { target: root; function onItemsChanged() { ring.requestPaint() } }
          Text { renderType: Text.NativeRendering; anchors.centerIn: parent; text: root.letters[modelData.provider] || "?"; font.family: Bridge.ModuleBus.family; font.bold: true; font.pixelSize: Bridge.ModuleBus.px(Style.font.caption - 1); color: root.fg }
        }
      }
    }
  }

  // On demand: a chip only from 75 %.
  Component {
    id: chipView
    Rectangle {
      implicitWidth: chipRow.implicitWidth + Style.space(12)
      height: Math.round(root.barSize * 0.72)
      y: Math.round((root.barSize - height) / 2)
      radius: Math.min(Style.cornerRadius, 3)
      color: Util.alpha(root.tightest ? root.tone(root.tightest.percent) : Color.accent, 0.16)
      Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: Style.space(5)
        Text { renderType: Text.NativeRendering; text: "\u{f04c5}"; font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.icon); color: root.tightest ? root.tone(root.tightest.percent) : root.fg }
        Text { renderType: Text.NativeRendering; text: root.tightest ? root.tightest.name + " " + root.shortLabel(root.tightest.label) + " " + Math.round(root.tightest.percent * 100) + "%" : ""; font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.bodySmall); color: root.fg }
      }
    }
  }

  // ---------------------------------------------------------------- popup
  property bool popupOpen: false
  readonly property bool opened: popupOpen
  property bool popoutSwitchClosing: false
  function open() { popupOpen = true }
  onPopupOpenChanged: if (popupOpen) Bridge.ModuleBus.requestUsageRefresh("limits")
  function close() { popupOpen = false }
  function togglePopup() { popupOpen = !popupOpen }
  function closeForPopoutSwitch() { popoutSwitchClosing = true; popupOpen = false; Qt.callLater(function() { root.popoutSwitchClosing = false }) }


  KeyboardPanel {
    id: popup
    anchorItem: root
    owner: root
    bar: root.bar
    open: root.popupOpen
    focusTarget: popupKeys
    contentWidth: Style.space(440)
    contentHeight: popup.fittedContentHeight(list.implicitHeight)

    // Fog look (test): the popup grows out of the bar as fog.
    Root.FogPanel { panel: popup; fog: Bridge.ModuleBus.fog; color: Bridge.ModuleBus.fogColor }

    Item {
      id: popupKeys
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: function(e) { root.close(); e.accepted = true }
      Column {
        id: list
        width: parent.width
        spacing: Style.space(8)
        Text { renderType: Text.NativeRendering; text: "AI quotas"; font.family: Bridge.ModuleBus.family; font.bold: true; font.pixelSize: Bridge.ModuleBus.px(Style.font.title); color: Color.popups.text }
        Repeater {
          model: root.items
          Row {
            required property var modelData
            width: list.width
            spacing: Style.space(8)
            Text { renderType: Text.NativeRendering; width: Style.space(150); elide: Text.ElideRight; text: modelData.name + " · " + root.shortLabel(modelData.label); font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.body); color: Color.popups.text }
            Rectangle {
              visible: modelData.percent >= 0
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(120); height: Style.space(6)
              color: Util.alpha(Color.popups.text, 0.12)
              Rectangle { width: parent.width * Math.min(1, Math.max(0, modelData.percent)); height: parent.height; color: root.tone(modelData.percent) }
            }
            Text { renderType: Text.NativeRendering;
              text: modelData.percent >= 0 ? Math.round(modelData.percent * 100) + "%" : modelData.value
              font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.body); color: Color.popups.text
            }
            Text { renderType: Text.NativeRendering; text: modelData.expired ? "reset · refreshing" : root.resetText(modelData.resetsAt); font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.caption); color: Util.alpha(Color.popups.text, 0.55) }
          }
        }
        Text { renderType: Text.NativeRendering; text: "Middle click refreshes · same selection as the AI usage widget"; font.family: Bridge.ModuleBus.family; font.pixelSize: Bridge.ModuleBus.px(Style.font.caption); color: Util.alpha(Color.popups.text, 0.5) }
      }
    }
  }
}
